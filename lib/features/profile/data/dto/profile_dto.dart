/// DTO del wire del perfil (`ataulfo-go/internal/adapters/httpsessions/dto.go`,
/// `profileResp` = `sessionResp` aplanado + `photo_url`). snake_case como el
/// resto de httpsessions. Sólo modela lo que el perfil muestra (identidad +
/// foto + app-state); ignora los campos de actividad (`unread_count`,
/// `last_message_*`) que viajan en la misma respuesta pero no se usan aquí.
///
/// `phone`, `display_name`, `muted_until` y `photo_url` son nullable (omitempty
/// del wire): grupo sin phone, sin nombre resuelto, sin silenciar, sin foto.
class ProfileResp {
  const ProfileResp({
    required this.chatLid,
    required this.kind,
    required this.phone,
    required this.displayName,
    required this.photoUrl,
    required this.isArchived,
    required this.isPinned,
    required this.isMarkedUnread,
    required this.mutedUntil,
  });

  factory ProfileResp.fromJson(Map<String, dynamic> json) {
    final chatLid = json['chat_lid'];
    final kind = json['kind'];
    final phone = json['phone'];
    final displayName = json['display_name'];
    final photoUrl = json['photo_url'];
    final isArchived = json['is_archived'];
    final isPinned = json['is_pinned'];
    final isMarkedUnread = json['is_marked_unread'];
    final mutedUntil = json['muted_until'];
    if (chatLid is! String ||
        kind is! String ||
        isArchived is! bool ||
        isPinned is! bool ||
        isMarkedUnread is! bool) {
      throw const FormatException('profileResp: clave obligatoria ausente');
    }
    for (final v in <Object?>[phone, displayName, photoUrl, mutedUntil]) {
      if (v != null && v is! String) {
        throw const FormatException('profileResp: campo opcional no es String');
      }
    }
    return ProfileResp(
      chatLid: chatLid,
      kind: kind,
      phone: phone as String?,
      displayName: displayName as String?,
      photoUrl: photoUrl as String?,
      isArchived: isArchived,
      isPinned: isPinned,
      isMarkedUnread: isMarkedUnread,
      mutedUntil: mutedUntil as String?,
    );
  }

  final String chatLid;
  final String kind;
  final String? phone;
  final String? displayName;
  final String? photoUrl;
  final bool isArchived;
  final bool isPinned;
  final bool isMarkedUnread;

  /// RFC3339 crudo del wire (o `null`). El mapper lo parsea a `DateTime`.
  final String? mutedUntil;
}
