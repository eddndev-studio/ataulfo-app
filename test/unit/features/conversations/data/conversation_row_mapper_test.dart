import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/mappers/conversation_row_mapper.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDb db;

  setUp(() => db = AppDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ConversationRow> roundTrip(
    Conversation c, {
    int syncedAtMs = 1,
  }) async {
    await db
        .into(db.conversations)
        .insert(
          ConversationRowMapper.entityToCompanion(
            'b1',
            c,
            syncedAtMs: syncedAtMs,
          ),
        );
    return (db.select(
      db.conversations,
    )..where((t) => t.chatLid.equals(c.chatLid))).getSingle();
  }

  test(
    'grupo con todos los campos: entity → row → entity preserva todo',
    () async {
      final original = Conversation(
        chatLid: 'lid-1',
        kind: ConversationKind.group,
        phone: null,
        isArchived: true,
        isPinned: true,
        isMarkedUnread: true,
        mutedUntil: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        displayName: 'Equipo',
        unreadCount: 7,
        lastMessagePreview: 'hola',
        lastMessageType: 'text',
        lastMessageDirection: 'INBOUND',
        lastMessageTimestampMs: 1699999999999,
      );
      final row = await roundTrip(original, syncedAtMs: 42);
      expect(ConversationRowMapper.rowToEntity(row), original);
      expect(row.syncedAtMs, 42);
    },
  );

  test('dm sin actividad ni muted: round-trip con defaults', () async {
    const original = Conversation(
      chatLid: 'lid-2',
      kind: ConversationKind.dm,
      phone: '5215550000',
      isArchived: false,
      isPinned: false,
      isMarkedUnread: false,
      mutedUntil: null,
    );
    final back = ConversationRowMapper.rowToEntity(await roundTrip(original));
    expect(back, original);
    expect(back.mutedUntil, isNull);
    expect(back.unreadCount, 0);
    expect(back.lastMessageTimestampMs, isNull);
  });
}
