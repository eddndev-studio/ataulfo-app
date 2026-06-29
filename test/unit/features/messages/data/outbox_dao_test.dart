import 'dart:convert';

import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/datasources/outbox_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;
  late OutboxDao dao;
  // Reloj inyectado: avanza con Durations para fijar el orden FIFO por createdAt.
  late DateTime now;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    now = DateTime.fromMillisecondsSinceEpoch(1000);
    dao = OutboxDao(db, now: () => now);
  });
  tearDown(() => db.close());

  Future<OutboxRow> only() async => (await db.select(db.outbox).get()).single;

  test(
    'enqueueSend inserta una fila pending con payload, token y timestamps',
    () async {
      final id = await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 't1',
        type: 'text',
        content: 'hola',
      );

      final row = await only();
      expect(row.id, id);
      expect(row.botId, 'b1');
      expect(row.chatLid, 'c1');
      expect(row.opType, 'send_message');
      expect(row.clientToken, 't1');
      expect(row.state, 'pending');
      expect(row.retryCount, 0);
      expect(row.createdAtMs, 1000);
      expect(row.updatedAtMs, 1000);
      expect(jsonDecode(row.payload), {'type': 'text', 'content': 'hola'});
    },
  );

  test('enqueueSend de media guarda mediaRef en el payload', () async {
    await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't1',
      type: 'image',
      content: '',
      mediaRef: 'ref-9',
    );
    expect(jsonDecode((await only()).payload), {
      'type': 'image',
      'content': '',
      'mediaRef': 'ref-9',
    });
  });

  test('enqueueSend de nota de voz guarda el waveform en el payload', () async {
    await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't1',
      type: 'ptt',
      content: '',
      mediaRef: 'ref-voz',
      waveform: const <int>[0, 50, 100],
    );
    expect(jsonDecode((await only()).payload), {
      'type': 'ptt',
      'content': '',
      'mediaRef': 'ref-voz',
      'waveform': <int>[0, 50, 100],
    });
  });

  test(
    'watchForChat emite las ops del chat en orden FIFO por createdAt',
    () async {
      await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'a',
        type: 'text',
        content: '1',
      );
      now = now.add(const Duration(seconds: 1));
      await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'b',
        type: 'text',
        content: '2',
      );
      now = now.add(const Duration(seconds: 1));
      await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'OTRO',
        clientToken: 'c',
        type: 'text',
        content: '3',
      );

      final rows = await dao.watchForChat('b1', 'c1').first;
      expect(rows.map((r) => r.clientToken), ['a', 'b']);
    },
  );

  test('pending devuelve sólo state=pending en orden FIFO', () async {
    final a = await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'a',
      type: 'text',
      content: '1',
    );
    now = now.add(const Duration(seconds: 1));
    await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'b',
      type: 'text',
      content: '2',
    );
    await dao.markFailedTerminal(a, errorKind: 'conflict'); // sale de la cola

    final rows = await dao.pending();
    expect(rows.map((r) => r.clientToken), ['b']);
  });

  test('markSending mueve a sending y refresca updatedAt', () async {
    final id = await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't',
      type: 'text',
      content: 'x',
    );
    now = now.add(const Duration(seconds: 5));
    await dao.markSending(id);

    final row = await only();
    expect(row.state, 'sending');
    expect(row.updatedAtMs, 6000);
  });

  test(
    'markRetry vuelve a pending, incrementa retryCount y guarda errorKind',
    () async {
      final id = await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 't',
        type: 'text',
        content: 'x',
      );
      await dao.markSending(id);
      await dao.markRetry(id, errorKind: 'network');
      await dao.markSending(id);
      await dao.markRetry(id, errorKind: 'timeout');

      final row = await only();
      expect(row.state, 'pending');
      expect(row.retryCount, 2);
      expect(row.errorKind, 'timeout');
    },
  );

  test('markFailedTerminal deja failed con su errorKind', () async {
    final id = await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't',
      type: 'text',
      content: 'x',
    );
    await dao.markFailedTerminal(id, errorKind: 'forbidden');

    final row = await only();
    expect(row.state, 'failed');
    expect(row.errorKind, 'forbidden');
  });

  test('deleteById elimina la fila (confirmación de envío)', () async {
    final id = await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 't',
      type: 'text',
      content: 'x',
    );
    await dao.deleteById(id);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test(
    'retryByToken revive la fila fallida (pending, retryCount 0, sin error)',
    () async {
      final id = await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'tok',
        type: 'text',
        content: 'x',
      );
      await dao.markSending(id);
      await dao.markRetry(id, errorKind: 'network'); // retryCount 1
      await dao.markFailedTerminal(id, errorKind: 'forbidden');

      await dao.retryByToken('b1', 'c1', 'tok');

      final row = await only();
      expect(row.state, 'pending');
      expect(row.retryCount, 0);
      expect(row.errorKind, isNull);
    },
  );

  test('deleteByToken borra sólo la fila de ese chat+token', () async {
    await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'tok',
      type: 'text',
      content: 'x',
    );
    await dao.enqueueSend(
      botId: 'b1',
      chatLid: 'c1',
      clientToken: 'otro',
      type: 'text',
      content: 'y',
    );

    await dao.deleteByToken('b1', 'c1', 'tok');

    final rows = await db.select(db.outbox).get();
    expect(rows.map((r) => r.clientToken), ['otro']);
  });

  test(
    'enqueueMarkRead coalesce por chat: reaperturas no acumulan (1 fila, la última gana)',
    () async {
      await dao.enqueueMarkRead(botId: 'b1', chatLid: 'c1');
      await dao.enqueueMarkRead(
        botId: 'b1',
        chatLid: 'c1',
        upToMessageId: 'm9',
      );

      final rows = await db.select(db.outbox).get();
      expect(rows.where((r) => r.opType == 'mark_read').length, 1);
      expect((jsonDecode(rows.single.payload) as Map)['upToMessageId'], 'm9');
    },
  );

  test('enqueueMarkRead NO borra una mark_read en vuelo (sending)', () async {
    final id = await dao.enqueueMarkRead(botId: 'b1', chatLid: 'c1');
    await dao.markSending(id); // en vuelo
    await dao.enqueueMarkRead(botId: 'b1', chatLid: 'c1');

    final rows = (await db.select(db.outbox).get())
        .where((r) => r.opType == 'mark_read')
        .toList();
    expect(rows.length, 2); // la sending sobrevive + la nueva pending
  });

  test(
    'enqueueReact coalesce por mensaje: mismo msg → 1 fila (último emoji)',
    () async {
      await dao.enqueueReact(
        botId: 'b1',
        chatLid: 'c1',
        messageId: 'M',
        emoji: '❤️',
      );
      await dao.enqueueReact(
        botId: 'b1',
        chatLid: 'c1',
        messageId: 'M',
        emoji: '👍',
      );

      final rows = (await db.select(db.outbox).get())
          .where((r) => r.opType == 'react')
          .toList();
      expect(rows.length, 1);
      expect((jsonDecode(rows.single.payload) as Map)['emoji'], '👍');
    },
  );

  test('enqueueReact a mensajes distintos NO coalesce (2 filas)', () async {
    await dao.enqueueReact(
      botId: 'b1',
      chatLid: 'c1',
      messageId: 'M',
      emoji: '❤️',
    );
    await dao.enqueueReact(
      botId: 'b1',
      chatLid: 'c1',
      messageId: 'N',
      emoji: '👍',
    );

    final rows = (await db.select(db.outbox).get())
        .where((r) => r.opType == 'react')
        .toList();
    expect(rows.length, 2);
  });

  test(
    'resetOrphanedSending rescata las sending a pending y cuenta cuántas',
    () async {
      final a = await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'a',
        type: 'text',
        content: '1',
      );
      final b = await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'b',
        type: 'text',
        content: '2',
      );
      await dao.enqueueSend(
        botId: 'b1',
        chatLid: 'c1',
        clientToken: 'c',
        type: 'text',
        content: '3',
      ); // pending
      await dao.markSending(a);
      await dao.markSending(b);

      final rescued = await dao.resetOrphanedSending();
      expect(rescued, 2);
      final pending = await dao.pending();
      expect(pending.length, 3); // las 3 quedan drenables
      expect(pending.every((r) => r.state == 'pending'), isTrue);
    },
  );
}
