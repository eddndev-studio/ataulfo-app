import 'dart:io';

import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_dao.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_datasource.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_events_datasource.dart';
import 'package:ataulfo/features/messages/data/datasources/outbox_dao.dart';
import 'package:ataulfo/features/messages/data/repositories/messages_repository_impl.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/message_page.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements MessagesDatasource {}

class _MockEvents extends Mock implements MessagesEventsDatasource {}

/// DAO cuya escritura local siempre falla con un error NO tipado (simula, por
/// ejemplo, un "database is locked" de drift). Usado para verificar que el
/// repositorio convierte errores no tipados a [UnknownMessagesFailure].
class _ThrowingDao implements MessagesDao {
  @override
  Stream<List<MessageRow>> watchThread(String botId, String chatLid) =>
      const Stream<List<MessageRow>>.empty();

  @override
  Future<void> upsertMessages(String botId, List<Message> msgs) =>
      throw StateError('boom');

  @override
  Future<void> applyStatus(
    String botId,
    String externalId,
    MessageStatus status,
  ) => throw StateError('boom');

  @override
  Future<({String? cursor, bool reachedStart})> threadCursor(
    String botId,
    String chatLid,
  ) async => (cursor: null, reachedStart: false);

  @override
  Future<void> setThreadCursor(
    String botId,
    String chatLid, {
    required String? oldestCursor,
    required bool reachedStart,
  }) async {}

  @override
  Future<void> deleteThread(String botId, String chatLid) =>
      throw StateError('boom');
}

// Mensajes de prueba sin mediaUrl (no se persiste) para que la igualdad
// entity==entity round-tripeada funcione sin divergencia en ese campo.
const _m1 = Message(
  externalId: 'ext-1',
  chatLid: 'chat-1',
  senderLid: 'sender-1',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'hola',
  mediaRef: null,
  quotedId: null,
  timestampMs: 1000,
  status: null,
);

const _m2 = Message(
  externalId: 'ext-2',
  chatLid: 'chat-1',
  senderLid: 'sender-1',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'mundo',
  mediaRef: null,
  quotedId: null,
  timestampMs: 2000,
  status: null,
);

const _mImg = Message(
  externalId: 'ext-img',
  chatLid: 'chat-1',
  senderLid: 'sender-1',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'image',
  content: '',
  mediaRef: 'tenant/o/media/x.png',
  mediaUrl: 'https://cdn/sig/x.png',
  quotedId: null,
  timestampMs: 1500,
  status: null,
);

void main() {
  late AppDb db;
  late _MockDs ds;
  late _MockEvents events;
  late OutboxDao outbox;
  late int syncCalls;
  late MessagesRepositoryImpl repo;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    ds = _MockDs();
    events = _MockEvents();
    outbox = OutboxDao(db);
    syncCalls = 0;
    repo = MessagesRepositoryImpl(
      datasource: ds,
      events: events,
      dao: MessagesDao(db),
      outbox: outbox,
      requestSync: () => syncCalls++,
    );
  });
  tearDown(() => db.close());

  // ────────────────────────────────────────────────────────
  // refreshThread
  // ────────────────────────────────────────────────────────

  test(
    'refreshThread escribe el snapshot HTTP y watchThread lo emite',
    () async {
      when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
        (_) async => const MessagePage(messages: [_m1], prevCursor: 'prev-1'),
      );
      await repo.refreshThread('b1', 'chat-1');
      expect(await repo.watchThread('b1', 'chat-1').first, [_m1]);
    },
  );

  test('watchThread re-inyecta la firma mediaUrl viva del fetch HTTP '
      '(la DB no persiste la firma efímera)', () async {
    when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
      (_) async => const MessagePage(messages: [_mImg], prevCursor: null),
    );
    await repo.refreshThread('b1', 'chat-1');

    final emitted = await repo.watchThread('b1', 'chat-1').first;
    expect(emitted.single.mediaRef, 'tenant/o/media/x.png');
    expect(
      emitted.single.mediaUrl,
      'https://cdn/sig/x.png',
      reason:
          'la firma viva del fetch debe llegar a la UI pese a que la DB '
          'no la persiste, para que el visor pueda bajar la media',
    );
  });

  test('watchThread re-inyecta la firma mediaUrl viva del SSE', () async {
    await repo.applyLiveMessage('b1', _mImg);

    final emitted = await repo.watchThread('b1', 'chat-1').first;
    expect(emitted.single.mediaUrl, 'https://cdn/sig/x.png');
  });

  test('refreshThread devuelve el prevCursor de la página HTTP', () async {
    when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
      (_) async => const MessagePage(messages: [_m1], prevCursor: 'cur-abc'),
    );
    final prev = await repo.refreshThread('b1', 'chat-1');
    expect(prev, 'cur-abc');
  });

  test(
    'refreshThread persiste el cursor para que loadOlder lo pueda leer',
    () async {
      when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
        (_) async => const MessagePage(messages: [_m1], prevCursor: 'cur-xyz'),
      );
      await repo.refreshThread('b1', 'chat-1');
      // El cursor persistido debe hacer que loadOlder lo use.
      when(() => ds.thread('b1', 'chat-1', cursor: 'cur-xyz')).thenAnswer(
        (_) async => const MessagePage(messages: [_m2], prevCursor: null),
      );
      final prev = await repo.loadOlder('b1', 'chat-1');
      expect(prev, isNull); // reachedStart
    },
  );

  // ────────────────────────────────────────────────────────
  // loadOlder
  // ────────────────────────────────────────────────────────

  test(
    'loadOlder lee el cursor persistido, trae el tramo más viejo y avanza el cursor',
    () async {
      // Siembra el cursor directamente en el DAO compartido.
      await MessagesDao(db).setThreadCursor(
        'b1',
        'chat-1',
        oldestCursor: 'cur-1',
        reachedStart: false,
      );
      when(() => ds.thread('b1', 'chat-1', cursor: 'cur-1')).thenAnswer(
        (_) async => const MessagePage(messages: [_m2], prevCursor: 'cur-0'),
      );
      final prev = await repo.loadOlder('b1', 'chat-1');
      expect(prev, 'cur-0');
      expect(await repo.watchThread('b1', 'chat-1').first, [_m2]);
    },
  );

  test(
    'loadOlder es no-op cuando reachedStart=true — devuelve null sin llamar al DS',
    () async {
      when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
        (_) async => const MessagePage(messages: [_m1], prevCursor: null),
      );
      // refreshThread con prevCursor=null marca reachedStart=true.
      await repo.refreshThread('b1', 'chat-1');
      final result = await repo.loadOlder('b1', 'chat-1');
      expect(result, isNull);
      // El DS sólo debe haber recibido UNA llamada (la del refresh).
      verify(() => ds.thread('b1', 'chat-1', cursor: null)).called(1);
      verifyNoMoreInteractions(ds);
    },
  );

  // ────────────────────────────────────────────────────────
  // Aislamiento de caché ante fallos de red
  // ────────────────────────────────────────────────────────

  test(
    'MessagesFailure en refreshThread no modifica la caché previa',
    () async {
      when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
        (_) async => const MessagePage(messages: [_m1], prevCursor: null),
      );
      await repo.refreshThread('b1', 'chat-1'); // siembra

      when(
        () => ds.thread('b1', 'chat-1', cursor: null),
      ).thenThrow(const MessagesNetworkFailure());

      await expectLater(
        repo.refreshThread('b1', 'chat-1'),
        throwsA(isA<MessagesNetworkFailure>()),
      );
      // La caché permanece con el snapshot anterior.
      expect(await repo.watchThread('b1', 'chat-1').first, [_m1]);
    },
  );

  // ────────────────────────────────────────────────────────
  // Error no tipado → UnknownMessagesFailure
  // ────────────────────────────────────────────────────────

  test(
    'error NO tipado de la escritura local → UnknownMessagesFailure',
    () async {
      final r = MessagesRepositoryImpl(
        datasource: ds,
        events: events,
        dao: _ThrowingDao(),
        outbox: OutboxDao(db),
        requestSync: () {},
      );
      when(() => ds.thread('b1', 'chat-1', cursor: null)).thenAnswer(
        (_) async => const MessagePage(messages: [_m1], prevCursor: null),
      );
      await expectLater(
        r.refreshThread('b1', 'chat-1'),
        throwsA(isA<UnknownMessagesFailure>()),
      );
    },
  );

  // ────────────────────────────────────────────────────────
  // applyLiveMessage / applyStatus — best-effort
  // ────────────────────────────────────────────────────────

  test('applyLiveMessage best-effort: no lanza ante fallo del DAO', () async {
    final r = MessagesRepositoryImpl(
      datasource: ds,
      events: events,
      dao: _ThrowingDao(),
      outbox: OutboxDao(db),
      requestSync: () {},
    );
    await expectLater(r.applyLiveMessage('b1', _m1), completes);
  });

  test('applyStatus best-effort: no lanza ante fallo del DAO', () async {
    final r = MessagesRepositoryImpl(
      datasource: ds,
      events: events,
      dao: _ThrowingDao(),
      outbox: OutboxDao(db),
      requestSync: () {},
    );
    await expectLater(
      r.applyStatus('b1', 'ext-1', MessageStatus.delivered),
      completes,
    );
  });

  test('applyLiveMessage con DAO real escribe el mensaje sin lanzar', () async {
    await expectLater(repo.applyLiveMessage('b1', _m1), completes);
    expect(await repo.watchThread('b1', 'chat-1').first, [_m1]);
  });

  // ────────────────────────────────────────────────────────
  // live delega a MessagesEventsDatasource
  // ────────────────────────────────────────────────────────

  test('live delega al datasource de eventos', () async {
    when(
      () => events.threadEvents('b1'),
    ).thenAnswer((_) => Stream.value(const LiveReconnected()));
    expect(await repo.live('b1').first, const LiveReconnected());
  });

  // ────────────────────────────────────────────────────────
  // S7: envío vía outbox + watchPending + retry/discard
  // ────────────────────────────────────────────────────────

  test(
    'send ENCOLA en el outbox (no pega al datasource) y dispara requestSync',
    () async {
      await repo.send(
        'b1',
        'chat-1',
        clientToken: 'tok',
        type: 'text',
        content: 'hola',
      );

      final rows = await outbox.pending();
      expect(rows.single.clientToken, 'tok');
      expect(syncCalls, 1);
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

  test('watchPending proyecta las filas del outbox a OutboxEntry', () async {
    await repo.send(
      'b1',
      'chat-1',
      clientToken: 'tok',
      type: 'text',
      content: 'hola',
    );

    final entries = await repo.watchPending('b1', 'chat-1').first;
    expect(entries.single.clientToken, 'tok');
    expect(entries.single.content, 'hola');
    expect(entries.single.isFailed, isFalse);
  });

  test(
    'watchPending refleja un fallo terminal (isFailed + errorKind)',
    () async {
      final id = await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'chat-1',
        clientToken: 'tok',
        type: 'text',
        content: 'x',
      );
      await outbox.markFailedTerminal(id, errorKind: 'forbidden');

      final entries = await repo.watchPending('b1', 'chat-1').first;
      expect(entries.single.isFailed, isTrue);
      expect(entries.single.errorKind, 'forbidden');
    },
  );

  test(
    'retrySend revive la fila (pending, retryCount 0) y dispara requestSync',
    () async {
      final id = await outbox.enqueueSend(
        botId: 'b1',
        chatLid: 'chat-1',
        clientToken: 'tok',
        type: 'text',
        content: 'x',
      );
      await outbox.markFailedTerminal(id, errorKind: 'forbidden');
      syncCalls = 0;

      await repo.retrySend('b1', 'chat-1', 'tok');

      final row = (await db.select(db.outbox).get()).single;
      expect(row.state, 'pending');
      expect(row.retryCount, 0);
      expect(row.errorKind, isNull);
      expect(syncCalls, 1);
    },
  );

  test('markRead ENCOLA un mark_read durable y dispara requestSync', () async {
    await repo.markRead('b1', 'chat-1', upToMessageId: 'm9');

    final rows = await db.select(db.outbox).get();
    expect(rows.single.opType, 'mark_read');
    expect(syncCalls, 1);
  });

  test(
    'markRead proyecta a la bandeja (write-through optimista de no-leídos)',
    () async {
      final calls = <List<String>>[];
      final r = MessagesRepositoryImpl(
        datasource: ds,
        events: events,
        dao: MessagesDao(db),
        outbox: OutboxDao(db),
        requestSync: () {},
        markConversationRead: (botId, chatLid) async =>
            calls.add(<String>[botId, chatLid]),
      );

      await r.markRead('b1', 'chat-7');
      await Future<void>.delayed(
        Duration.zero,
      ); // el proyector es fire-and-forget

      expect(calls, <List<String>>[
        <String>['b1', 'chat-7'],
      ]);
    },
  );

  test('react ENCOLA un react durable y dispara requestSync', () async {
    await repo.react('b1', 'chat-1', messageId: 'M', emoji: '👍');

    final rows = await db.select(db.outbox).get();
    expect(rows.single.opType, 'react');
    expect(syncCalls, 1);
  });

  test('discardSend borra la fila del outbox', () async {
    await outbox.enqueueSend(
      botId: 'b1',
      chatLid: 'chat-1',
      clientToken: 'tok',
      type: 'text',
      content: 'x',
    );
    await repo.discardSend('b1', 'chat-1', 'tok');
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'durabilidad real: un envío encolado sobrevive a cerrar y reabrir la DB',
    () async {
      // DB respaldada en archivo: probar persistencia REAL (no sólo visibilidad
      // por conexión compartida en memoria).
      final dir = await Directory.systemTemp.createTemp('outbox_durable');
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/app.sqlite');

      final db1 = AppDb.forTesting(NativeDatabase(file));
      final repo1 = MessagesRepositoryImpl(
        datasource: ds,
        events: events,
        dao: MessagesDao(db1),
        outbox: OutboxDao(db1),
        requestSync: () {},
      );
      await repo1.send(
        'b1',
        'chat-1',
        clientToken: 'tok',
        type: 'text',
        content: 'sobrevive',
      );
      await db1.close(); // "cierre de la app"

      // "Reapertura": una DB nueva sobre el MISMO archivo.
      final db2 = AppDb.forTesting(NativeDatabase(file));
      addTearDown(() => db2.close());
      final repo2 = MessagesRepositoryImpl(
        datasource: ds,
        events: events,
        dao: MessagesDao(db2),
        outbox: OutboxDao(db2),
        requestSync: () {},
      );
      final entries = await repo2.watchPending('b1', 'chat-1').first;
      expect(entries.single.clientToken, 'tok');
      expect(entries.single.content, 'sobrevive');
    },
  );

  // ────────────────────────────────────────────────────────
  // editMessage / deleteMessage (corrección del operador)
  // ────────────────────────────────────────────────────────

  Message out(
    String ext, {
    String content = 'precio: \$40',
    int? editedAtMs,
    int? revokedAtMs,
  }) => Message(
    externalId: ext,
    chatLid: 'chat-1',
    senderLid: 'sender-1',
    kind: MessageKind.dm,
    direction: MessageDirection.outbound,
    type: 'text',
    content: content,
    mediaRef: null,
    quotedId: null,
    timestampMs: 1000,
    status: MessageStatus.sent,
    editedAtMs: editedAtMs,
    revokedAtMs: revokedAtMs,
  );

  test(
    'editMessage aplica write-through el DTO devuelto por el servidor',
    () async {
      await MessagesDao(db).upsertMessages('bot-1', [out('ext-out')]);
      when(
        () => ds.editMessage(
          'bot-1',
          'chat-1',
          messageId: 'ext-out',
          newText: 'precio: \$50',
        ),
      ).thenAnswer(
        (_) async => out('ext-out', content: 'precio: \$50', editedAtMs: 9000),
      );

      await repo.editMessage(
        'bot-1',
        'chat-1',
        messageId: 'ext-out',
        newText: 'precio: \$50',
      );

      final rows = await repo.watchThread('bot-1', 'chat-1').first;
      final m = rows.singleWhere((r) => r.externalId == 'ext-out');
      expect(m.content, 'precio: \$50');
      expect(m.editedAtMs, 9000);
    },
  );

  test('deleteMessage sella revokedAtMs en la fila local', () async {
    await MessagesDao(db).upsertMessages('bot-1', [out('ext-out')]);
    when(
      () => ds.revokeMessage('bot-1', 'chat-1', messageId: 'ext-out'),
    ).thenAnswer((_) async => out('ext-out', revokedAtMs: 9500));

    await repo.deleteMessage('bot-1', 'chat-1', messageId: 'ext-out');

    final rows = await repo.watchThread('bot-1', 'chat-1').first;
    expect(rows.single.revokedAtMs, 9500);
  });

  test(
    'editMessage propaga la failure del datasource sin tocar la fila',
    () async {
      await MessagesDao(db).upsertMessages('bot-1', [out('ext-out')]);
      when(
        () => ds.editMessage(
          any(),
          any(),
          messageId: any(named: 'messageId'),
          newText: any(named: 'newText'),
        ),
      ).thenThrow(const MessagesConflictFailure());

      await expectLater(
        repo.editMessage('bot-1', 'chat-1', messageId: 'ext-out', newText: 'x'),
        throwsA(isA<MessagesConflictFailure>()),
      );
      final rows = await repo.watchThread('bot-1', 'chat-1').first;
      expect(rows.single.editedAtMs, isNull);
    },
  );
}
