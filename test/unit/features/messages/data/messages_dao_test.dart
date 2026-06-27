import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_dao.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;
  late MessagesDao dao;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    dao = MessagesDao(db);
  });
  tearDown(() => db.close());

  // Fábrica mínima de mensajes de prueba.
  Message msg(
    String externalId, {
    String chatLid = 'chat-1',
    MessageDirection direction = MessageDirection.outbound,
    MessageStatus? status = MessageStatus.sent,
    int timestampMs = 1000,
    String content = 'hola',
    String? mediaRef,
    String? quotedId,
  }) => Message(
    externalId: externalId,
    chatLid: chatLid,
    senderLid: 'sender-1',
    kind: MessageKind.dm,
    direction: direction,
    type: 'text',
    content: content,
    mediaRef: mediaRef,
    quotedId: quotedId,
    timestampMs: timestampMs,
    status: status,
  );

  // ────────────────────────────────────────────────────────
  // watchThread — orden ASC
  // ────────────────────────────────────────────────────────

  test(
    'watchThread devuelve mensajes ASC por (timestampMs, externalId)',
    () async {
      await dao.upsertMessages('b1', [
        msg('ext-2', timestampMs: 200),
        msg('ext-1', timestampMs: 100),
        msg(
          'ext-3a',
          timestampMs: 200,
        ), // mismo ts, desempate externalId 3a < 3b
        msg('ext-3b', timestampMs: 200),
      ]);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      expect(rows.map((r) => r.externalId).toList(), [
        'ext-1',
        'ext-2',
        'ext-3a',
        'ext-3b',
      ]);
    },
  );

  // ────────────────────────────────────────────────────────
  // upsertMessages — monotonía del status
  // ────────────────────────────────────────────────────────

  test(
    'upsertMessages MONÓTONO — READ existente no retrocede a SENT',
    () async {
      await dao.upsertMessages('b1', [
        msg('ext-a', status: MessageStatus.read),
      ]);
      await dao.upsertMessages('b1', [
        msg('ext-a', status: MessageStatus.sent),
      ]);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      expect(rows.single.status, MessageStatus.read.name);
    },
  );

  test('upsertMessages MONÓTONO — SENT existente avanza a DELIVERED', () async {
    await dao.upsertMessages('b1', [msg('ext-a', status: MessageStatus.sent)]);
    await dao.upsertMessages('b1', [
      msg('ext-a', status: MessageStatus.delivered),
    ]);
    final rows = await dao.watchThread('b1', 'chat-1').first;
    expect(rows.single.status, MessageStatus.delivered.name);
  });

  test(
    'upsertMessages MONÓTONO — DELIVERED existente no retrocede a SENT',
    () async {
      await dao.upsertMessages('b1', [
        msg('ext-a', status: MessageStatus.delivered),
      ]);
      await dao.upsertMessages('b1', [
        msg('ext-a', status: MessageStatus.sent),
      ]);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      expect(rows.single.status, MessageStatus.delivered.name);
    },
  );

  test('upsertMessages — status nulo en INBOUND persiste como nulo', () async {
    await dao.upsertMessages('b1', [
      msg('ext-inbound', direction: MessageDirection.inbound, status: null),
    ]);
    final rows = await dao.watchThread('b1', 'chat-1').first;
    expect(rows.single.status, isNull);
  });

  // ────────────────────────────────────────────────────────
  // applyStatus — monotonía en recibos
  // ────────────────────────────────────────────────────────

  test('applyStatus avanza el status de un mensaje existente', () async {
    await dao.upsertMessages('b1', [msg('ext-a', status: MessageStatus.sent)]);
    await dao.applyStatus('b1', 'ext-a', MessageStatus.read);
    final rows = await dao.watchThread('b1', 'chat-1').first;
    expect(rows.single.status, MessageStatus.read.name);
  });

  test('applyStatus no retrocede (DELIVERED no baja a SENT)', () async {
    await dao.upsertMessages('b1', [
      msg('ext-a', status: MessageStatus.delivered),
    ]);
    await dao.applyStatus('b1', 'ext-a', MessageStatus.sent);
    final rows = await dao.watchThread('b1', 'chat-1').first;
    expect(rows.single.status, MessageStatus.delivered.name);
  });

  test(
    'applyStatus es no-op para un mensaje ausente (no lanza, no inserta)',
    () async {
      await dao.applyStatus('b1', 'ext-inexistente', MessageStatus.delivered);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      expect(rows, isEmpty);
    },
  );

  // ────────────────────────────────────────────────────────
  // Persistencia de campos
  // ────────────────────────────────────────────────────────

  test(
    'upsertMessages persiste content, timestampMs y campos opcionales',
    () async {
      await dao.upsertMessages('b1', [
        msg(
          'ext-a',
          content: 'texto original',
          timestampMs: 42000,
          mediaRef: 'ref/img/abc',
          quotedId: 'ext-ref',
        ),
      ]);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      final row = rows.single;
      expect(row.content, 'texto original');
      expect(row.timestampMs, 42000);
      expect(row.mediaRef, 'ref/img/abc');
      expect(row.quotedId, 'ext-ref');
    },
  );

  // ────────────────────────────────────────────────────────
  // threadCursor / setThreadCursor — round-trip
  // ────────────────────────────────────────────────────────

  test(
    'threadCursor devuelve defaults cuando no existe entrada previa',
    () async {
      final c = await dao.threadCursor('b1', 'chat-nueva');
      expect(c.cursor, isNull);
      expect(c.reachedStart, false);
    },
  );

  test(
    'setThreadCursor + threadCursor round-trip con cursor y reachedStart=false',
    () async {
      await dao.setThreadCursor(
        'b1',
        'chat-1',
        oldestCursor: 'cur-abc',
        reachedStart: false,
      );
      final c = await dao.threadCursor('b1', 'chat-1');
      expect(c.cursor, 'cur-abc');
      expect(c.reachedStart, false);
    },
  );

  test(
    'setThreadCursor actualiza al reachedStart=true con cursor nulo',
    () async {
      await dao.setThreadCursor(
        'b1',
        'chat-1',
        oldestCursor: 'cur-abc',
        reachedStart: false,
      );
      await dao.setThreadCursor(
        'b1',
        'chat-1',
        oldestCursor: null,
        reachedStart: true,
      );
      final c = await dao.threadCursor('b1', 'chat-1');
      expect(c.cursor, isNull);
      expect(c.reachedStart, true);
    },
  );

  // ────────────────────────────────────────────────────────
  // Tenencia — aislamiento por botId
  // ────────────────────────────────────────────────────────

  test(
    'mismo externalId en distintos botId coexiste sin interferencia',
    () async {
      await dao.upsertMessages('b1', [
        msg('ext-a', status: MessageStatus.sent),
      ]);
      await dao.upsertMessages('b2', [
        msg('ext-a', status: MessageStatus.delivered),
      ]);
      final b1 = await dao.watchThread('b1', 'chat-1').first;
      final b2 = await dao.watchThread('b2', 'chat-1').first;
      expect(b1.single.status, MessageStatus.sent.name);
      expect(b2.single.status, MessageStatus.delivered.name);
    },
  );

  test(
    'watchThread aísla por botId — mensajes de otro bot no aparecen',
    () async {
      await dao.upsertMessages('b1', [msg('ext-a')]);
      await dao.upsertMessages('b2', [msg('ext-b')]);
      final rows = await dao.watchThread('b1', 'chat-1').first;
      expect(rows.map((r) => r.externalId).toList(), ['ext-a']);
    },
  );
}
