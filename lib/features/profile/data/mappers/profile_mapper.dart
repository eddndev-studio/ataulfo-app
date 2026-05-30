import '../../domain/entities/chat_profile.dart';
import '../dto/profile_dto.dart';

/// Traduce el DTO del wire a la entidad de dominio. Pura. `kind` se resuelve
/// fail-loud a `isGroup` (un valor distinto de DM/GROUP es drift de contrato y
/// rompe); `muted_until` RFC3339 → `DateTime` (UTC del wire), `null` queda
/// `null`. Un `muted_until` malformado lanza `FormatException`.
class ProfileMapper {
  const ProfileMapper._();

  static ChatProfile respToEntity(ProfileResp r) => ChatProfile(
    chatLid: r.chatLid,
    isGroup: _isGroup(r.kind),
    phone: r.phone,
    displayName: r.displayName,
    photoUrl: r.photoUrl,
    isArchived: r.isArchived,
    isPinned: r.isPinned,
    isMarkedUnread: r.isMarkedUnread,
    mutedUntil: r.mutedUntil == null ? null : DateTime.parse(r.mutedUntil!),
  );

  static bool _isGroup(String kind) => switch (kind) {
    'GROUP' => true,
    'DM' => false,
    _ => throw FormatException('profile: kind desconocido', kind),
  };
}
