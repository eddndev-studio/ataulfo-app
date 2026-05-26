/// DTO del wire de `GET /auth/memberships` (contrato post-S02).
///
/// Espeja `membershipResp` del backend: claves snake_case del wire viven
/// aquí; el dominio expone `camelCase` vía mapper. `role` viaja crudo
/// (set cerrado del backend: OWNER/ADMIN/SUPERVISOR/WORKER) — el cliente
/// no traduce nombres del wire al dominio.
class MembershipResp {
  const MembershipResp({
    required this.orgId,
    required this.orgName,
    required this.role,
  });

  factory MembershipResp.fromJson(Map<String, dynamic> json) {
    final orgId = json['org_id'];
    final orgName = json['org_name'];
    final role = json['role'];
    if (orgId is! String || orgName is! String || role is! String) {
      throw const FormatException('membershipResp: clave obligatoria ausente');
    }
    return MembershipResp(orgId: orgId, orgName: orgName, role: role);
  }

  final String orgId;
  final String orgName;
  final String role;
}
