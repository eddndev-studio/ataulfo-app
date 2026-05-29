/// DTO del wire S07 (`ataulfo-go/internal/adapters/httpsessions/dto.go`,
/// `GET /sessions/:botId`). Mantiene los nombres `snake_case` y los tipos
/// crudos del wire; la traducción a dominio (kind→enum, muted_until→DateTime)
/// vive en `ConversationsMapper`.
///
/// `phone` y `muted_until` son nullable porque el handler usa `omitempty`:
/// un grupo no manda `phone`, y una conversación no silenciada no manda
/// `muted_until`.
class ConversationResp {
  const ConversationResp({
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
  });

  factory ConversationResp.fromJson(Map<String, dynamic> json) {
    final chatLid = json['chat_lid'];
    final kind = json['kind'];
    final phone = json['phone'];
    final isArchived = json['is_archived'];
    final isPinned = json['is_pinned'];
    final isMarkedUnread = json['is_marked_unread'];
    final mutedUntil = json['muted_until'];
    if (chatLid is! String ||
        kind is! String ||
        isArchived is! bool ||
        isPinned is! bool ||
        isMarkedUnread is! bool) {
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
    return ConversationResp(
      chatLid: chatLid,
      kind: kind,
      phone: phone as String?,
      isArchived: isArchived,
      isPinned: isPinned,
      isMarkedUnread: isMarkedUnread,
      mutedUntil: mutedUntil as String?,
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
}
