import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/mappers/conversation_row_mapper.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;

  setUp(() => db = AppDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Conversation> roundTrip(Conversation conversation) async {
    await db
        .into(db.conversations)
        .insert(
          ConversationRowMapper.entityToCompanion(
            conversation,
            orgId: 'org-1',
            syncedAtMs: 42,
          ),
        );
    final row = await db.select(db.conversations).getSingle();
    expect(row.syncedAtMs, 42);
    return ConversationRowMapper.rowToEntity(row);
  }

  test(
    'round-trip preserva procedencia, atención y etiquetas internas',
    () async {
      final original = Conversation(
        botId: 'bot-1',
        chatLid: 'lid-1',
        kind: ConversationKind.group,
        phone: null,
        isArchived: true,
        isPinned: true,
        isMarkedUnread: true,
        mutedUntil: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        displayName: 'Distribuidores del norte',
        unreadCount: 7,
        lastMessagePreview: 'Confirmado',
        lastMessageType: 'text',
        lastMessageDirection: 'INBOUND',
        lastMessageTimestampMs: 1699999999999,
        needsAttention: true,
        assistantId: 'assistant-1',
        assistantName: 'Ventas regionales',
        channelName: 'Ventas Guatemala',
        channelType: 'WA_UNOFFICIAL',
        channelIdentifier: '+502 2440 9012',
        labels: const <ConversationLabel>[
          ConversationLabel(id: 'vip', name: 'VIP', color: '#C57B57'),
        ],
      );

      expect(await roundTrip(original), original);
    },
  );

  test(
    'labelsJson inválido falla fuerte para que repo tipifique el error',
    () async {
      await db
          .into(db.conversations)
          .insert(
            ConversationsCompanion.insert(
              orgId: 'org-1',
              botId: 'bot-1',
              chatLid: 'lid-1',
              kind: 'dm',
              syncedAtMs: 1,
              assistantId: 'assistant-1',
              assistantName: 'Ventas',
              channelName: 'Canal',
              channelType: 'WA_UNOFFICIAL',
              labelsJson: '{roto',
            ),
          );
      final row = await db.select(db.conversations).getSingle();

      expect(
        () => ConversationRowMapper.rowToEntity(row),
        throwsFormatException,
      );
    },
  );
}
