import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../../core/db/app_db.dart';
import '../../domain/entities/conversation.dart';

class ConversationRowMapper {
  const ConversationRowMapper._();

  static Conversation rowToEntity(ConversationRow row) => Conversation(
    botId: row.botId,
    chatLid: row.chatLid,
    kind: ConversationKind.values.byName(row.kind),
    phone: row.phone,
    isArchived: row.isArchived,
    isPinned: row.isPinned,
    isMarkedUnread: row.isMarkedUnread,
    mutedUntil: row.mutedUntilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.mutedUntilMs!),
    displayName: row.displayName,
    unreadCount: row.unreadCount,
    lastMessagePreview: row.lastMessagePreview,
    lastMessageType: row.lastMessageType,
    lastMessageDirection: row.lastMessageDirection,
    lastMessageTimestampMs: row.lastMessageTimestampMs,
    needsAttention: row.needsAttention,
    assistantId: row.assistantId,
    assistantName: row.assistantName,
    channelName: row.channelName,
    channelType: row.channelType,
    channelIdentifier: row.channelIdentifier,
    labels: _decodeLabels(row.labelsJson),
  );

  static ConversationsCompanion entityToCompanion(
    Conversation conversation, {
    required String orgId,
    required int syncedAtMs,
  }) => ConversationsCompanion.insert(
    orgId: orgId,
    botId: conversation.botId,
    chatLid: conversation.chatLid,
    kind: conversation.kind.name,
    assistantId: conversation.assistantId,
    assistantName: conversation.assistantName,
    channelName: conversation.channelName,
    channelType: conversation.channelType,
    labelsJson: _encodeLabels(conversation.labels),
    syncedAtMs: syncedAtMs,
    phone: Value(conversation.phone),
    isArchived: Value(conversation.isArchived),
    isPinned: Value(conversation.isPinned),
    isMarkedUnread: Value(conversation.isMarkedUnread),
    mutedUntilMs: Value(conversation.mutedUntil?.millisecondsSinceEpoch),
    displayName: Value(conversation.displayName),
    unreadCount: Value(conversation.unreadCount),
    lastMessagePreview: Value(conversation.lastMessagePreview),
    lastMessageType: Value(conversation.lastMessageType),
    lastMessageDirection: Value(conversation.lastMessageDirection),
    lastMessageTimestampMs: Value(conversation.lastMessageTimestampMs),
    needsAttention: Value(conversation.needsAttention),
    channelIdentifier: Value(conversation.channelIdentifier),
  );

  static String _encodeLabels(List<ConversationLabel> labels) =>
      jsonEncode(<Map<String, String>>[
        for (final label in labels)
          <String, String>{
            'id': label.id,
            'name': label.name,
            'color': label.color,
          },
      ]);

  static List<ConversationLabel> _decodeLabels(String encoded) {
    final raw = jsonDecode(encoded);
    if (raw is! List<dynamic>) {
      throw const FormatException('labelsJson no es una lista');
    }
    return raw
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('labelsJson contiene un item inválido');
          }
          final id = item['id'];
          final name = item['name'];
          final color = item['color'];
          if (id is! String || name is! String || color is! String) {
            throw const FormatException('labelsJson contiene campos inválidos');
          }
          return ConversationLabel(id: id, name: name, color: color);
        })
        .toList(growable: false);
  }
}
