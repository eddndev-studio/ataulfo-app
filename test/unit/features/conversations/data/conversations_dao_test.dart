import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;
  late ConversationsDao dao;
  late String activeOrgId;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    activeOrgId = 'org-a';
    dao = ConversationsDao(db, activeOrgId: () => activeOrgId);
  });
  tearDown(() => db.close());

  ConversationsCompanion row(
    String botId,
    String chatLid, {
    int? timestamp,
    bool pinned = false,
    int unread = 0,
    bool needsAttention = false,
    String preview = 'inicial',
    String orgId = 'org-a',
  }) => ConversationsCompanion.insert(
    orgId: orgId,
    botId: botId,
    chatLid: chatLid,
    kind: 'dm',
    syncedAtMs: 1,
    assistantId: 'assistant-1',
    assistantName: 'Ventas regionales',
    channelName: 'Ventas $botId',
    channelType: 'WA_UNOFFICIAL',
    labelsJson: '[]',
    isPinned: Value(pinned),
    unreadCount: Value(unread),
    needsAttention: Value(needsAttention),
    lastMessagePreview: Value(preview),
    lastMessageTimestampMs: Value.absentIfNull(timestamp),
  );

  test('watchAll preserva mismo chatLid en dos canales', () async {
    await dao.upsertPage(<ConversationsCompanion>[
      row('b1', 'same', timestamp: 10),
      row('b2', 'same', timestamp: 20),
    ]);

    final rows = await dao.watchAll().first;

    expect(rows, hasLength(2));
    expect(rows.map((r) => r.botId).toSet(), <String>{'b1', 'b2'});
  });

  test('watchAll y clearCached quedan aislados por organización', () async {
    await dao.upsertPage(<ConversationsCompanion>[
      row('bot-a', 'chat-a'),
      row('bot-b', 'chat-b', orgId: 'org-b'),
    ]);

    expect((await dao.watchAll().first).map((item) => item.botId), <String>[
      'bot-a',
    ]);

    await dao.clearCached();
    expect(await dao.watchAll().first, isEmpty);

    activeOrgId = 'org-b';
    expect((await dao.watchAll().first).map((item) => item.botId), <String>[
      'bot-b',
    ]);
  });

  test(
    'upsertPage conserva páginas anteriores y actualiza duplicados',
    () async {
      await dao.upsertPage(<ConversationsCompanion>[
        row('b1', 'first', timestamp: 30),
        row('b1', 'duplicate', timestamp: 20),
      ]);
      await dao.upsertPage(<ConversationsCompanion>[
        row('b1', 'duplicate', timestamp: 40, preview: 'actualizado'),
        row('b2', 'third', timestamp: 10),
      ]);

      final rows = await dao.watchAll().first;
      expect(rows, hasLength(3));
      expect(
        rows.singleWhere((r) => r.chatLid == 'duplicate').lastMessagePreview,
        'actualizado',
      );
    },
  );

  test('watchAll ordena fijadas, actividad y luego identidad', () async {
    await dao.upsertPage(<ConversationsCompanion>[
      row('b2', 'same-ts', timestamp: 20),
      row('b1', 'same-ts', timestamp: 20),
      row('b1', 'old', timestamp: 10),
      row('b1', 'pinned', timestamp: 1, pinned: true),
    ]);

    final rows = await dao.watchAll().first;

    expect(rows.map((r) => '${r.botId}/${r.chatLid}').toList(), <String>[
      'b1/pinned',
      'b1/same-ts',
      'b2/same-ts',
      'b1/old',
    ]);
  });

  test('clearUnread limpia contador, marca manual y atención', () async {
    await dao.upsertPage(<ConversationsCompanion>[
      row('b1', 'chat', unread: 4, needsAttention: true),
    ]);

    await dao.clearUnread('b1', 'chat');

    final result = (await dao.watchAll().first).single;
    expect(result.unreadCount, 0);
    expect(result.isMarkedUnread, isFalse);
    expect(result.needsAttention, isFalse);
  });

  test('markNeedsAttention sólo toca la identidad compuesta exacta', () async {
    await dao.upsertPage(<ConversationsCompanion>[
      row('b1', 'same'),
      row('b2', 'same'),
    ]);

    await dao.markNeedsAttention('b2', 'same');

    final rows = await dao.watchAll().first;
    expect(rows.singleWhere((r) => r.botId == 'b1').needsAttention, isFalse);
    expect(rows.singleWhere((r) => r.botId == 'b2').needsAttention, isTrue);
  });

  test('clearCached elimina sólo la proyección reconstruible', () async {
    await dao.upsertPage(<ConversationsCompanion>[row('b1', 'chat')]);

    await dao.clearCached();

    expect(await dao.watchAll().first, isEmpty);
  });
}
