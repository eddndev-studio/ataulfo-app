import 'package:drift/drift.dart' show Value;

import '../../../../core/db/app_db.dart';
import '../../domain/entities/conversation.dart';

/// Traduce entre la entidad de dominio [Conversation] y la fila drift
/// [ConversationRow]. El `kind` se guarda por su `.name`; `mutedUntil` como
/// epoch en milisegundos (mismo instante absoluto al ida y vuelta).
class ConversationRowMapper {
  const ConversationRowMapper._();

  static Conversation rowToEntity(ConversationRow r) => Conversation(
    chatLid: r.chatLid,
    kind: ConversationKind.values.byName(r.kind),
    phone: r.phone,
    isArchived: r.isArchived,
    isPinned: r.isPinned,
    isMarkedUnread: r.isMarkedUnread,
    mutedUntil: r.mutedUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.mutedUntilMs!),
    displayName: r.displayName,
    unreadCount: r.unreadCount,
    lastMessagePreview: r.lastMessagePreview,
    lastMessageType: r.lastMessageType,
    lastMessageDirection: r.lastMessageDirection,
    lastMessageTimestampMs: r.lastMessageTimestampMs,
  );

  static ConversationsCompanion entityToCompanion(
    String botId,
    Conversation c, {
    required int syncedAtMs,
  }) => ConversationsCompanion.insert(
    botId: botId,
    chatLid: c.chatLid,
    kind: c.kind.name,
    syncedAtMs: syncedAtMs,
    phone: Value(c.phone),
    isArchived: Value(c.isArchived),
    isPinned: Value(c.isPinned),
    isMarkedUnread: Value(c.isMarkedUnread),
    mutedUntilMs: Value(c.mutedUntil?.millisecondsSinceEpoch),
    displayName: Value(c.displayName),
    unreadCount: Value(c.unreadCount),
    lastMessagePreview: Value(c.lastMessagePreview),
    lastMessageType: Value(c.lastMessageType),
    lastMessageDirection: Value(c.lastMessageDirection),
    lastMessageTimestampMs: Value(c.lastMessageTimestampMs),
  );
}
