/// Identidad derivada del access token (`GET /auth/me`).
///
/// Stateless: el backend la devuelve sin golpe a BD porque el JWT ya lleva
/// `user_id`, `org_id` y `role`. El cliente la trata como entidad de
/// dominio (sin nombres del wire) — el mapper traduce `MeResp` ⇄ `Identity`.
class Identity {
  const Identity({
    required this.userId,
    required this.orgId,
    required this.role,
  });

  final String userId;
  final String orgId;
  final String role;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Identity &&
        other.userId == userId &&
        other.orgId == orgId &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(userId, orgId, role);
}
