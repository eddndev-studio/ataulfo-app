/// Una org del operador decorada con su nombre legible (S02
/// `GET /auth/memberships`).
///
/// Espeja la fila `membershipResp` del wire sin nombres del wire: los
/// mappers traducen DTO ⇄ entidad. El cliente NO traduce `role` (mantiene
/// el string del set cerrado del backend: OWNER/ADMIN/SUPERVISOR/WORKER)
/// — la presentación lo humaniza si quiere.
class Membership {
  const Membership({
    required this.orgId,
    required this.orgName,
    required this.role,
  });

  final String orgId;
  final String orgName;
  final String role;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Membership &&
        other.orgId == orgId &&
        other.orgName == orgName &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(orgId, orgName, role);
}
