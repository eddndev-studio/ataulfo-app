/// Resultado de aceptar una invitación pendiente
/// (`POST /auth/invitations/accept-pending`).
///
/// La membership nueva ya existe tras esta respuesta, pero no está activa: el
/// switch a la org lo hace el operador tocándola en la lista de organizaciones.
/// Lleva el nombre legible para confirmar el ingreso ("Ya eres parte de …").
class AcceptedInvitation {
  const AcceptedInvitation({
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
    return other is AcceptedInvitation &&
        other.orgId == orgId &&
        other.orgName == orgName &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(orgId, orgName, role);
}
