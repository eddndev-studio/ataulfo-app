import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/messages/data/datasources/messages_dao.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `deleteThread` — la limpieza local tras el 204 del vaciado (S07 RF#10):
/// borra los mensajes de ESE chat y su cursor de backfill, sin tocar los
/// hilos vecinos ni sus cursores.
void main() {
  late AppDb db;
  late MessagesDao dao;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    dao = MessagesDao(db);
  });
  tearDown(() => db.close());

  Message msg(String externalId, {String chatLid = 'chat-1'}) => Message(
    externalId: externalId,
    chatLid: chatLid,
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

  test('borra los mensajes y el cursor SOLO del chat indicado', () async {
    await dao.upsertMessages('b1', [msg('e1'), msg('e2')]);
    await dao.upsertMessages('b1', [msg('e3', chatLid: 'chat-2')]);
    await dao.setThreadCursor(
      'b1',
      'chat-1',
      oldestCursor: 'cur-1',
      reachedStart: false,
    );
    await dao.setThreadCursor(
      'b1',
      'chat-2',
      oldestCursor: 'cur-2',
      reachedStart: false,
    );

    await dao.deleteThread('b1', 'chat-1');

    expect(await dao.watchThread('b1', 'chat-1').first, isEmpty);
    expect(await dao.watchThread('b1', 'chat-2').first, hasLength(1));
    // El cursor del chat vaciado desaparece (el hilo arranca fresco, sin
    // paginar histórico que ya no existe); el vecino conserva el suyo.
    final cleared = await dao.threadCursor('b1', 'chat-1');
    expect(cleared.cursor, isNull);
    final kept = await dao.threadCursor('b1', 'chat-2');
    expect(kept.cursor, 'cur-2');
  });

  test('idempotente: chat sin filas locales no es error', () async {
    await dao.deleteThread('b1', 'chat-vacio');
  });
}
