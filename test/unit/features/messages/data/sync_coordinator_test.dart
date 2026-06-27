import 'dart:async';
import 'dart:convert';

import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/core/network/connectivity_monitor.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_dao.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_datasource.dart';
import 'package:ataulfo/features/messages/data/datasources/outbox_dao.dart';
import 'package:ataulfo/features/messages/data/sync/sync_coordinator.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements MessagesDatasource {}

class _FakeConnectivity implements ConnectivityMonitor {
  final _ctrl = StreamController<bool>.broadcast();
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _ctrl.stream;

  void emit(bool v) => _ctrl.add(v);
  Future<void> dispose() => _ctrl.close();
}

/// Espera que nunca completa: por defecto los re-drains por backoff quedan
/// aparcados, así cada test inspecciona el resultado de UNA pasada sin loops.
Future<void> _neverDelay(Duration _) => Completer<void>().future;

/// MessagesDao cuyo upsert siempre lanza un error NO-MessagesFailure (simula un
/// error de DB transitorio en la transacción de reconciliación).
class _ThrowingMessagesDao extends MessagesDao {
  _ThrowingMessagesDao(super.db);
  @override
  Future<void> upsertMessages(String botId, List<Message> msgs) async {
    throw StateError('db boom');
  }
}

void main() {
  late AppDb db;
  late OutboxDao outbox;
  late MessagesDao messages;
  late _MockDs ds;
  late _FakeConnectivity conn;
  SyncCoordinator? coord;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    outbox = OutboxDao(db);
    messages = MessagesDao(db);
    ds = _MockDs();
    conn = _FakeConnectivity();
  });
  tearDown(() async {
    await coord?.close();
    await conn.dispose();
    await db.close();
  });

  SyncCoordinator make({AsyncDelay delay = _neverDelay}) {
    return coord = SyncCoordinator(
      db: db,
      outbox: outbox,
      messages: messages,
      datasource: ds,
      connectivity: conn,
      delay: delay,
    );
  }

  Message msg(
    String externalId, {
    String content = 'hola',
    MessageStatus? status = MessageStatus.sent,
    int timestampMs = 1000,
  }) => Message(
    externalId: externalId,
    chatLid: 'c1',
    senderLid: 's1',
    kind: MessageKind.dm,
    direction: MessageDirection.outbound,
    type: 'text',
    content: content,
    mediaRef: null,
    quotedId: null,
    timestampMs: timestampMs,
    status: status,
  );

  // Stub uniforme de send para los named args.
  void stubSend(Future<Message> Function(Invocation) answer) {
    when(
      () => ds.send(
        any(),
        any(),
        clientToken: any(named: 'clientToken'),
        type: any(named: 'type'),
        content: any(named: 'content'),
        mediaRef: any(named: 'mediaRef'),
      ),
    ).thenAnswer(answer);
  }

  String tokenOf(Invocation inv) => inv.namedArguments[#clientToken] as String;

  Future<int> seedSending(String token, {String chatLid = 'c1'}) {
    return db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            botId: 'b1',
            chatLid: chatLid,
            opType: 'send_message',
            clientToken: Value(token),
            payload: jsonEncode({'type': 'text', 'content': 'hola'}),
            state: const Value('sending'),
            createdAtMs: 1000,
            updatedAtMs: 1000,
          ),
        );
  }

  test('drena un envío encolado: llama send con el token y reconcilia '
      '(escribe el mensaje, borra la fila)', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't1',
      type: 'text',
      content: 'hola',
    );
    stubSend((_) async => msg('wamid-1'));

    await make().start();

    final msgs = await db.select(db.messages).get();
    expect(msgs.map((m) => m.externalId), ['wamid-1']);
    expect(await db.select(db.outbox).get(), isEmpty);
    verify(
      () => ds.send(
        'b1',
        'c1',
        clientToken: 't1',
        type: 'text',
        content: 'hola',
        mediaRef: null,
      ),
    ).called(1);
  });

  test('huérfana sending ya aceptada por el server: reset + replay idempotente '
      '(mismo token ⇒ mismo externalId) NO duplica', () async {
    await seedSending('t2'); // crash a media-POST; el server ya la tenía
    var sends = 0;
    stubSend((inv) async {
      sends++;
      expect(tokenOf(inv), 't2');
      return msg('wamid-2'); // 200-replay: SIEMPRE el mismo mensaje
    });

    await make().start(); // resetOrphanedSending → drain → replay → reconcile
    await coord!.drain(); // otra pasada: la cola ya está vacía

    final msgs = await db.select(db.messages).get();
    expect(msgs.map((m) => m.externalId), ['wamid-2']); // exactamente uno
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(
      sends,
      1,
      reason: 'el replay corre una vez; la 2ª pasada no reenvía',
    );
  });

  test('fallo reintentable: markRetry (sigue pending) y NUNCA se vuelve '
      'terminal por contador', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't3',
      type: 'text',
      content: 'x',
    );
    stubSend((_) async => throw const MessagesNetworkFailure());

    final c = make();
    for (var i = 0; i < 6; i++) {
      await c.drain();
    }

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'pending', reason: 'red transitoria: jamás terminal');
    expect(row.retryCount, 6);
    expect(row.errorKind, 'network');
  });

  test('fallo terminal (409 conflict): failed y no se reintenta', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't4',
      type: 'text',
      content: 'x',
    );
    var sends = 0;
    stubSend((_) async {
      sends++;
      throw const MessagesConflictFailure();
    });

    final c = make();
    await c.drain();
    await c.drain(); // no debe reenviar una failed

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'failed');
    expect(row.errorKind, 'conflict');
    expect(sends, 1);
  });

  test('auto-cura en línea: un 5xx programa un re-drain por backoff que, al '
      'recuperarse el server, reconcilia', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't5',
      type: 'text',
      content: 'x',
    );
    final gate = Completer<void>();
    var fail = true;
    stubSend((_) async {
      if (fail) throw const MessagesServerFailure();
      return msg('wamid-5');
    });

    final c = make(delay: (_) => gate.future);
    await c
        .drain(); // 5xx → markRetry (pending) → programa backoff (espera gate)

    expect((await db.select(db.outbox).get()).single.state, 'pending');

    fail = false; // el server se recupera
    gate.complete();
    await pumpEventQueue();

    expect((await db.select(db.messages).get()).map((m) => m.externalId), [
      'wamid-5',
    ]);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'single-flight: dos drains concurrentes no reenvían dos veces',
    () async {
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 't6',
        type: 'text',
        content: 'x',
      );
      final gate = Completer<void>();
      var sends = 0;
      stubSend((_) async {
        sends++;
        await gate.future; // mantiene el primer drain en vuelo
        return msg('wamid-6');
      });

      final c = make();
      final d1 = c.drain();
      final d2 = c.drain(); // _draining true → se colapsa
      gate.complete();
      await Future.wait([d1, d2]);

      expect(sends, 1);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('orden FIFO por chat: si la 1ª falla reintentable, la 2ª del mismo chat '
      'no se adelanta', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'A',
      type: 'text',
      content: '1',
    );
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'B',
      type: 'text',
      content: '2',
    );
    final sent = <String>[];
    stubSend((inv) async {
      final t = tokenOf(inv);
      sent.add(t);
      if (t == 'A') throw const MessagesNetworkFailure();
      return msg('wamid-B');
    });

    await make().drain();

    expect(sent, ['A'], reason: 'B no se envía hasta que A pase');
    final rows = await db.select(db.outbox).get();
    expect(rows.map((r) => r.clientToken).toSet(), {'A', 'B'});
    expect(rows.every((r) => r.state == 'pending'), isTrue);
  });

  test('fence por generación: reset() durante el POST en vuelo evita escribir '
      'tras la purga de sesión', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't8',
      type: 'text',
      content: 'x',
    );
    final gate = Completer<void>();
    stubSend((_) async {
      await gate.future;
      return msg('wamid-8');
    });

    final c = make();
    final draining = c.drain(); // se aparca dentro de _handleSend
    await pumpEventQueue();
    c.reset(); // cierre de sesión: bump de generación
    gate.complete();
    await draining;

    // No se escribió el mensaje ni se borró la fila (la generación cambió).
    expect(await db.select(db.messages).get(), isEmpty);
    expect((await db.select(db.outbox).get()).single.state, 'sending');
  });

  test(
    'reconciliación monótona: un eco previo DELIVERED no se degrada a SENT',
    () async {
      await db
          .into(db.messages)
          .insert(
            MessagesCompanion.insert(
              botId: 'b1',
              externalId: 'wamid-9',
              chatLid: 'c1',
              senderLid: 's1',
              kind: 'dm',
              direction: 'outbound',
              type: 'text',
              content: 'hola',
              timestampMs: 1000,
              syncedAtMs: 0,
              status: const Value('delivered'),
            ),
          );
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 't9',
        type: 'text',
        content: 'hola',
      );
      stubSend((_) async => msg('wamid-9', status: MessageStatus.sent));

      await make().drain();

      final row = (await db.select(db.messages).get()).single;
      expect(
        row.status,
        'delivered',
        reason: 'el upsert monótono no retrocede',
      );
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  // Stubs por defecto de mark_read/react (éxito) para los tests de S8.
  void stubMarkRead({Future<int> Function(Invocation)? answer}) {
    when(
      () =>
          ds.markRead(any(), any(), upToMessageId: any(named: 'upToMessageId')),
    ).thenAnswer(answer ?? (_) async => 1);
  }

  void stubReact({Future<void> Function(Invocation)? answer}) {
    when(
      () => ds.react(
        any(),
        any(),
        messageId: any(named: 'messageId'),
        emoji: any(named: 'emoji'),
      ),
    ).thenAnswer(answer ?? (_) async {});
  }

  test('drena un mark_read: llama markRead y borra la fila', () async {
    await outbox.enqueueMarkRead(
      botId: 'b1',
      chatLid: 'c1',
      upToMessageId: 'm9',
    );
    stubMarkRead();

    await make().drain();

    verify(() => ds.markRead('b1', 'c1', upToMessageId: 'm9')).called(1);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('drena un react: llama react y borra la fila', () async {
    await outbox.enqueueReact(
      botId: 'b1',
      chatLid: 'c1',
      messageId: 'M',
      emoji: '👍',
    );
    stubReact();

    await make().drain();

    verify(() => ds.react('b1', 'c1', messageId: 'M', emoji: '👍')).called(1);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('mark_read con fallo reintentable → pending (no terminal)', () async {
    await outbox.enqueueMarkRead(botId: 'b1', chatLid: 'c1');
    stubMarkRead(answer: (_) async => throw const MessagesTimeoutFailure());

    await make().drain();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'pending');
    expect(row.errorKind, 'timeout');
  });

  test('react con fallo terminal (403) → failed', () async {
    await outbox.enqueueReact(
      botId: 'b1',
      chatLid: 'c1',
      messageId: 'M',
      emoji: '👍',
    );
    stubReact(answer: (_) async => throw const MessagesForbiddenFailure());

    await make().drain();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'failed');
    expect(row.errorKind, 'forbidden');
  });

  test(
    'FIFO: un envío fallido NO bloquea un mark_read del mismo chat',
    () async {
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'A',
        type: 'text',
        content: '1',
      );
      await outbox.enqueueMarkRead(botId: 'b1', chatLid: 'c1');
      stubSend(
        (_) async => throw const MessagesNetworkFailure(),
      ); // envío falla
      stubMarkRead();

      await make().drain();

      verify(() => ds.markRead('b1', 'c1', upToMessageId: null)).called(1);
      final rows = await db.select(db.outbox).get();
      expect(rows.single.opType, 'send_message'); // sólo el envío quedó en cola
      expect(rows.single.state, 'pending');
    },
  );

  test(
    'FIFO: un mark_read fallido NO bloquea un envío del mismo chat',
    () async {
      await outbox.enqueueMarkRead(botId: 'b1', chatLid: 'c1'); // primero
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'A',
        type: 'text',
        content: '1',
      );
      stubMarkRead(answer: (_) async => throw const MessagesNetworkFailure());
      stubSend((_) async => msg('wamid-A'));

      await make().drain();

      // El envío se ejecutó pese al mark_read fallido anterior.
      expect((await db.select(db.messages).get()).map((m) => m.externalId), [
        'wamid-A',
      ]);
      final rows = await db.select(db.outbox).get();
      expect(rows.single.opType, 'mark_read');
      expect(rows.single.state, 'pending');
    },
  );

  test(
    'react: una reacción vieja superada por una más nueva NO se reenvía',
    () async {
      // Dos reacciones al mismo mensaje coexisten (p. ej. la 1ª quedó en vuelo /
      // huérfana y volvió a pending junto a la 2ª). Sembradas directas para
      // simular esa carrera (enqueueReact las habría coalescido).
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: 'b1',
              chatLid: 'c1',
              opType: 'react',
              payload: jsonEncode({'messageId': 'M', 'emoji': '❤️'}),
              createdAtMs: 1,
              updatedAtMs: 1,
            ),
          );
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: 'b1',
              chatLid: 'c1',
              opType: 'react',
              payload: jsonEncode({'messageId': 'M', 'emoji': '👍'}),
              createdAtMs: 2,
              updatedAtMs: 2,
            ),
          );
      final reacted = <String>[];
      stubReact(
        answer: (inv) async {
          reacted.add(inv.namedArguments[#emoji] as String);
        },
      );

      await make().drain();

      // Sólo la más nueva (👍) se POSTeó; la vieja (❤️) se descartó sin enviar.
      expect(reacted, ['👍']);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('reconexión: un evento online dispara el drain', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't10',
      type: 'text',
      content: 'x',
    );
    stubSend((_) async => msg('wamid-10'));

    make(); // se suscribe a onlineChanges
    conn.emit(true);
    await pumpEventQueue();

    expect((await db.select(db.messages).get()).map((m) => m.externalId), [
      'wamid-10',
    ]);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('independencia entre chats: un fallo reintentable en un chat NO bloquea '
      'otro chat', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'k1',
      type: 'text',
      content: '1',
    );
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c2',
      clientToken: 'k2',
      type: 'text',
      content: '2',
    );
    stubSend((inv) async {
      if (tokenOf(inv) == 'k1') throw const MessagesNetworkFailure();
      return msg('wamid-c2');
    });

    await make().drain();

    final c2Done = (await db.select(db.messages).get()).map(
      (m) => m.externalId,
    );
    expect(c2Done, ['wamid-c2'], reason: 'c2 se envía pese al fallo de c1');
    final rows = await db.select(db.outbox).get();
    expect(rows.map((r) => r.clientToken), [
      'k1',
    ], reason: 'sólo c1 sigue en cola');
    expect(rows.single.state, 'pending');
  });

  test('tabla de clasificación: cada failure cae en pending(reintentable) o '
      'failed(terminal) con su errorKind', () async {
    final cases = <(MessagesFailure, String, String)>[
      (const MessagesNetworkFailure(), 'pending', 'network'),
      (const MessagesTimeoutFailure(), 'pending', 'timeout'),
      (const MessagesServerFailure(), 'pending', 'server'),
      (const MessagesNotConnectedFailure(), 'pending', 'not_connected'),
      (const MessagesWireFailure(), 'pending', 'wire'),
      (const MessagesConflictFailure(), 'failed', 'conflict'),
      (const MessagesValidationFailure(), 'failed', 'validation'),
      (const MessagesForbiddenFailure(), 'failed', 'forbidden'),
      (const MessagesNotFoundFailure(), 'failed', 'not_found'),
      (const MessagesBotPausedFailure(), 'failed', 'bot_paused'),
      (const UnknownMessagesFailure(), 'failed', 'unknown'),
    ];
    MessagesFailure? toThrow;
    stubSend((_) async => throw toThrow!);
    final c = make();

    var i = 0;
    for (final (failure, state, kind) in cases) {
      await db.delete(db.outbox).go();
      toThrow = failure;
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'k$i',
        type: 'text',
        content: 'x',
      );
      i++;
      await c.drain();
      final row = (await db.select(db.outbox).get()).single;
      expect(row.state, state, reason: '${failure.runtimeType}');
      expect(row.errorKind, kind, reason: '${failure.runtimeType}');
    }
  });

  test('_again: el trabajo encolado DURANTE un drain se procesa en la pasada '
      'extra (no queda varado)', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'r1',
      type: 'text',
      content: '1',
    );
    final gate = Completer<void>();
    final sent = <String>[];
    stubSend((inv) async {
      final t = tokenOf(inv);
      sent.add(t);
      if (t == 'r1') await gate.future; // mantiene el primer drain en vuelo
      return msg('wamid-$t');
    });

    final c = make();
    final d1 = c.drain(); // procesa r1, aparcado en el gate
    await pumpEventQueue();
    // r2 se encola MIENTRAS r1 está en vuelo (no estaba en el pending() inicial).
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'r2',
      type: 'text',
      content: '2',
    );
    final d2 = c.drain(); // _draining=true → se colapsa en _again
    gate.complete();
    await Future.wait([d1, d2]);

    expect(sent.toSet(), {'r1', 'r2'});
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('backoff escala (base, 2x, 4x) y se reinicia tras un éxito', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'e1',
      type: 'text',
      content: 'x',
    );
    final delays = <Duration>[];
    final gates = <Completer<void>>[];
    Future<void> rec(Duration d) {
      delays.add(d);
      final g = Completer<void>();
      gates.add(g);
      return g.future;
    }

    var ok = false;
    stubSend((_) async {
      if (!ok) throw const MessagesServerFailure();
      return msg('wamid-ok');
    });

    final c = make(delay: rec);
    await c.drain(); // falla → programa delays[0]
    gates[0].complete();
    await pumpEventQueue(); // re-drain falla → delays[1]
    gates[1].complete();
    await pumpEventQueue(); // re-drain falla → delays[2]

    expect(delays, [
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
    ]);

    ok = true;
    gates[2].complete();
    await pumpEventQueue(); // re-drain con éxito → reinicia backoffRound
    expect(await db.select(db.outbox).get(), isEmpty);

    ok = false;
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'e2',
      type: 'text',
      content: 'y',
    );
    await c.drain(); // nuevo fallo: el backoff arranca de base otra vez
    expect(delays.length, 4);
    expect(delays[3], const Duration(seconds: 2));
  });

  test(
    'reset() libera el backoff: la sesión siguiente programa el suyo',
    () async {
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 's1',
        type: 'text',
        content: 'x',
      );
      final delays = <Duration>[];
      Future<void> rec(Duration d) {
        delays.add(d);
        return Completer<void>().future; // aparca (nunca completa)
      }

      stubSend((_) async => throw const MessagesNetworkFailure());
      final c = make(delay: rec);
      await c
          .drain(); // falla → programa (delays[0]), _retryScheduled queda true
      expect(delays.length, 1);

      c.reset(); // cierre de sesión: debe liberar el flag y reiniciar el round
      await db.delete(db.outbox).go();
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 's2',
        type: 'text',
        content: 'y',
      );
      await c.drain();

      expect(
        delays.length,
        2,
        reason: 'reset liberó _retryScheduled → se reprograma',
      );
      expect(
        delays[1],
        const Duration(seconds: 2),
        reason: 'reset reinició el round a base',
      );
    },
  );

  test(
    'payload corrupto: terminal corrupt_payload, sin llamar a send',
    () async {
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: 'b1',
              chatLid: 'c1',
              opType: 'send_message',
              clientToken: const Value('t'),
              payload: 'no-es-json',
              createdAtMs: 1,
              updatedAtMs: 1,
            ),
          );
      stubSend((_) async => msg('x'));

      await make().drain();

      final row = (await db.select(db.outbox).get()).single;
      expect(row.state, 'failed');
      expect(row.errorKind, 'corrupt_payload');
      verifyNever(
        () => ds.send(
          any(),
          any(),
          clientToken: any(named: 'clientToken'),
          type: any(named: 'type'),
          content: any(named: 'content'),
          mediaRef: any(named: 'mediaRef'),
        ),
      );
    },
  );

  test('opType no soportado: terminal unsupported_op, sin send', () async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            botId: 'b1',
            chatLid: 'c1',
            opType: 'apply_label', // un opType que el coordinador no maneja
            payload: jsonEncode({'label': 'x'}),
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );
    stubSend((_) async => msg('x'));

    await make().drain();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'failed');
    expect(row.errorKind, 'unsupported_op');
    verifyNever(
      () => ds.send(
        any(),
        any(),
        clientToken: any(named: 'clientToken'),
        type: any(named: 'type'),
        content: any(named: 'content'),
        mediaRef: any(named: 'mediaRef'),
      ),
    );
  });

  test('send sin clientToken: terminal missing_token, sin send', () async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            botId: 'b1',
            chatLid: 'c1',
            opType: 'send_message',
            payload: jsonEncode({'type': 'text', 'content': 'x'}),
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );
    stubSend((_) async => msg('x'));

    await make().drain();

    final row = (await db.select(db.outbox).get()).single;
    expect(row.state, 'failed');
    expect(row.errorKind, 'missing_token');
    verifyNever(
      () => ds.send(
        any(),
        any(),
        clientToken: any(named: 'clientToken'),
        type: any(named: 'type'),
        content: any(named: 'content'),
        mediaRef: any(named: 'mediaRef'),
      ),
    );
  });

  test(
    'error de DB al reconciliar revierte a pending (no atasca en sending)',
    () async {
      await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 't',
        type: 'text',
        content: 'x',
      );
      stubSend((_) async => msg('wamid-x'));
      final c = coord = SyncCoordinator(
        db: db,
        outbox: outbox,
        messages: _ThrowingMessagesDao(db),
        datasource: ds,
        connectivity: conn,
        delay: _neverDelay,
      );

      await c.drain();

      final row = (await db.select(db.outbox).get()).single;
      expect(
        row.state,
        'pending',
        reason: 'un error local NO debe dejar la fila en sending',
      );
      expect(row.errorKind, 'local');
      expect(await db.select(db.messages).get(), isEmpty);
    },
  );
}
