class ConversationLabelResp {
  const ConversationLabelResp({
    required this.id,
    required this.name,
    required this.color,
  });

  factory ConversationLabelResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];
    if (id is! String || name is! String || color is! String) {
      throw const FormatException('conversationLabelResp malformado');
    }
    return ConversationLabelResp(id: id, name: name, color: color);
  }

  final String id;
  final String name;
  final String color;
}

/// DTO de una fila de `GET /inbox/conversations`.
class ConversationResp {
  const ConversationResp({
    required this.botId,
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
    required this.displayName,
    required this.unreadCount,
    required this.needsAttention,
    required this.lastMessagePreview,
    required this.lastMessageType,
    required this.lastMessageDirection,
    required this.lastMessageTimestampMs,
    required this.assistantId,
    required this.assistantName,
    required this.channelName,
    required this.channelType,
    required this.channelIdentifier,
    required this.labels,
  });

  factory ConversationResp.fromJson(Map<String, dynamic> json) {
    final botId = json['bot_id'];
    final chatLid = json['chat_lid'];
    final kind = json['kind'];
    final phone = json['phone'];
    final displayName = json['display_name'];
    final archived = json['is_archived'];
    final pinned = json['is_pinned'];
    final markedUnread = json['is_marked_unread'];
    final mutedUntil = json['muted_until'];
    final unreadCount = json['unread_count'];
    final needsAttention = json['needs_attention'];
    final lastPreview = json['last_message_preview'];
    final lastType = json['last_message_type'];
    final lastDirection = json['last_message_direction'];
    final lastTimestamp = json['last_message_timestamp_ms'];
    final assistantId = json['assistant_id'];
    final assistantName = json['assistant_name'];
    final channelName = json['channel_name'];
    final channelType = json['channel_type'];
    final channelIdentifier = json['channel_identifier'];
    final rawLabels = json['labels'];

    if (botId is! String ||
        chatLid is! String ||
        kind is! String ||
        archived is! bool ||
        pinned is! bool ||
        markedUnread is! bool ||
        unreadCount is! int ||
        needsAttention is! bool ||
        assistantId is! String ||
        assistantName is! String ||
        channelName is! String ||
        channelType is! String ||
        rawLabels is! List<dynamic>) {
      throw const FormatException(
        'conversationResp: clave obligatoria ausente',
      );
    }
    for (final nullable in <Object?>[
      phone,
      displayName,
      mutedUntil,
      lastPreview,
      lastType,
      lastDirection,
      channelIdentifier,
    ]) {
      if (nullable != null && nullable is! String) {
        throw const FormatException(
          'conversationResp: String nullable inválido',
        );
      }
    }
    if (lastTimestamp != null && lastTimestamp is! int) {
      throw const FormatException('conversationResp: timestamp inválido');
    }

    final labels = rawLabels
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('conversationResp: label inválida');
          }
          return ConversationLabelResp.fromJson(raw);
        })
        .toList(growable: false);

    return ConversationResp(
      botId: botId,
      chatLid: chatLid,
      kind: kind,
      phone: phone as String?,
      isArchived: archived,
      isPinned: pinned,
      isMarkedUnread: markedUnread,
      mutedUntil: mutedUntil as String?,
      displayName: displayName as String?,
      unreadCount: unreadCount,
      needsAttention: needsAttention,
      lastMessagePreview: lastPreview as String?,
      lastMessageType: lastType as String?,
      lastMessageDirection: lastDirection as String?,
      lastMessageTimestampMs: lastTimestamp as int?,
      assistantId: assistantId,
      assistantName: assistantName,
      channelName: channelName,
      channelType: channelType,
      channelIdentifier: channelIdentifier as String?,
      labels: labels,
    );
  }

  final String botId;
  final String chatLid;
  final String kind;
  final String? phone;
  final bool isArchived;
  final bool isPinned;
  final bool isMarkedUnread;
  final String? mutedUntil;
  final String? displayName;
  final int unreadCount;
  final bool needsAttention;
  final String? lastMessagePreview;
  final String? lastMessageType;
  final String? lastMessageDirection;
  final int? lastMessageTimestampMs;
  final String assistantId;
  final String assistantName;
  final String channelName;
  final String channelType;
  final String? channelIdentifier;
  final List<ConversationLabelResp> labels;
}

class ConversationsPageResp {
  const ConversationsPageResp({required this.items, required this.nextCursor});

  factory ConversationsPageResp.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final nextCursor = json['next_cursor'];
    if (rawItems is! List<dynamic> ||
        (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('conversationsPageResp malformado');
    }
    final items = rawItems
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('conversationsPageResp: item inválido');
          }
          return ConversationResp.fromJson(raw);
        })
        .toList(growable: false);
    return ConversationsPageResp(
      items: items,
      nextCursor: nextCursor as String?,
    );
  }

  final List<ConversationResp> items;
  final String? nextCursor;
}
