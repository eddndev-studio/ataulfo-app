/// DTO del wire S07 (`ataulfo-go/internal/adapters/httpsessions/dto.go`,
/// `GET /sessions/:botId`). Mantiene los nombres `snake_case` y los tipos
/// crudos del wire; la traducción a dominio (kind→enum, muted_until→DateTime)
/// vive en `ConversationsMapper`.
///
/// `phone`, `display_name`, `muted_until` y los `last_message_*` son nullable
/// porque el handler usa `omitempty`: un grupo no manda `phone`, una sin
/// silenciar no manda `muted_until`, y una sin mensajes no manda el
/// último-mensaje. `unread_count` SÍ viaja siempre (no es omitempty): su
/// ausencia es drift de contrato y falla fuerte.
class ConversationResp {
  const ConversationResp({
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
    this.displayName,
    this.unreadCount = 0,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageDirection,
    this.lastMessageTimestampMs,
  });

  factory ConversationResp.fromJson(Map<String, dynamic> json) {
    final chatLid = json['chat_lid'];
    final kind = json['kind'];
    final phone = json['phone'];
    final displayName = json['display_name'];
    final isArchived = json['is_archived'];
    final isPinned = json['is_pinned'];
    final isMarkedUnread = json['is_marked_unread'];
    final mutedUntil = json['muted_until'];
    final unreadCount = json['unread_count'];
    final lastPreview = json['last_message_preview'];
    final lastType = json['last_message_type'];
    final lastDirection = json['last_message_direction'];
    final lastTimestampMs = json['last_message_timestamp_ms'];
    if (chatLid is! String ||
        kind is! String ||
        isArchived is! bool ||
        isPinned is! bool ||
        isMarkedUnread is! bool ||
        unreadCount is! int) {
      throw const FormatException(
        'conversationResp: clave obligatoria ausente',
      );
    }
    if (phone != null && phone is! String) {
      throw const FormatException(
        'conversationResp: phone no es String ni null',
      );
    }
    if (mutedUntil != null && mutedUntil is! String) {
      throw const FormatException(
        'conversationResp: muted_until no es String ni null',
      );
    }
    if (displayName != null && displayName is! String) {
      throw const FormatException(
        'conversationResp: display_name no es String ni null',
      );
    }
    if ((lastPreview != null && lastPreview is! String) ||
        (lastType != null && lastType is! String) ||
        (lastDirection != null && lastDirection is! String)) {
      throw const FormatException(
        'conversationResp: last_message_* no es String ni null',
      );
    }
    if (lastTimestampMs != null && lastTimestampMs is! int) {
      throw const FormatException(
        'conversationResp: last_message_timestamp_ms no es int ni null',
      );
    }
    return ConversationResp(
      chatLid: chatLid,
      kind: kind,
      phone: phone as String?,
      isArchived: isArchived,
      isPinned: isPinned,
      isMarkedUnread: isMarkedUnread,
      mutedUntil: mutedUntil as String?,
      displayName: displayName as String?,
      unreadCount: unreadCount,
      lastMessagePreview: lastPreview as String?,
      lastMessageType: lastType as String?,
      lastMessageDirection: lastDirection as String?,
      lastMessageTimestampMs: lastTimestampMs as int?,
    );
  }

  final String chatLid;
  final String kind;
  final String? phone;
  final bool isArchived;
  final bool isPinned;
  final bool isMarkedUnread;

  /// RFC3339 crudo del wire (o `null`). El mapper lo parsea a `DateTime`.
  final String? mutedUntil;

  /// Nombre visible del wire (push-name DM / subject grupo), o `null`.
  final String? displayName;

  /// Contador de no-leídos; siempre presente (badge 0 incluido).
  final int unreadCount;

  /// Último-mensaje del wire (crudo). `null` cuando la conversación no tiene
  /// mensajes; los cuatro viajan juntos.
  final String? lastMessagePreview;
  final String? lastMessageType;
  final String? lastMessageDirection;
  final int? lastMessageTimestampMs;
}
