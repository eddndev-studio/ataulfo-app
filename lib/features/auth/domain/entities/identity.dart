/// Identidad derivada del access token (`GET /auth/me`).
///
/// `userId`, `orgId` y `role` salen de los claims del JWT sin tocar BD.
/// `email` lo lee el backend del repo de usuarios por id (paga un SELECT
/// por request): el JWT no transporta email porque desvinculaciones y
/// rotaciones quedarían stale a través de la familia de refresh — el
/// cliente recibe email vivo a costa de un SELECT por `/auth/me`.
///
/// El cliente la trata como entidad de dominio (sin nombres del wire);
/// el mapper traduce `MeResp` ⇄ `Identity`.
class Identity {
  const Identity({
    required this.userId,
    required this.orgId,
    required this.role,
    required this.email,
  });

  final String userId;
  final String orgId;
  final String role;
  final String email;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Identity &&
        other.userId == userId &&
        other.orgId == orgId &&
        other.role == role &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(userId, orgId, role, email);
}
