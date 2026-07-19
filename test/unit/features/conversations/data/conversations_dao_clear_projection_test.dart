import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `clearThreadProjection` — write-through optimista del vaciado de historial
/// (S07 RF#10): la fila de la bandeja pierde su preview de último mensaje y
/// sus no-leídos (esos mensajes ya no existen), pero la conversación misma y
/// sus vecinas quedan intactas. El snapshot del backend reconcilia después.
void main() {
  late AppDb db;
  late ConversationsDao dao;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    dao = ConversationsDao(db, activeOrgId: () => 'org-1');
  });
  tearDown(() => db.close());

  ConversationsCompanion conv(String chatLid) => ConversationsCompanion.insert(
    orgId: 'org-1',
    botId: 'b1',
    chatLid: chatLid,
    kind: 'dm',
    assistantId: 'assistant-1',
    assistantName: 'Ventas',
    channelName: 'Principal',
    channelType: 'WA_UNOFFICIAL',
    labelsJson: '[]',
    syncedAtMs: 0,
    unreadCount: const Value(3),
    lastMessagePreview: const Value('hola'),
    lastMessageType: const Value('text'),
    lastMessageDirection: const Value('INBOUND'),
    lastMessageTimestampMs: const Value(1700),
  );

  test('vacía la proyección del chat sin tocar a las vecinas', () async {
    await dao.upsertPage([conv('chat-1'), conv('chat-2')]);

    await dao.clearThreadProjection('b1', 'chat-1');

    final rows = await dao.watchAll().first;
    final cleared = rows.singleWhere((r) => r.chatLid == 'chat-1');
    expect(cleared.unreadCount, 0);
    expect(cleared.lastMessagePreview, isNull);
    expect(cleared.lastMessageTimestampMs, isNull);
    final kept = rows.singleWhere((r) => r.chatLid == 'chat-2');
    expect(kept.unreadCount, 3);
    expect(kept.lastMessagePreview, 'hola');
  });

  test('no inserta filas ausentes (chat aún no cacheado)', () async {
    await dao.clearThreadProjection('b1', 'chat-fantasma');
    expect(await dao.watchAll().first, isEmpty);
  });
}
