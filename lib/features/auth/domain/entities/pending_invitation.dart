/// Una invitación pendiente dirigida al correo de la sesión actual
/// (`GET /auth/invitations/pending`).
///
/// A diferencia de [Membership], no representa una org a la que ya se
/// pertenece: es una oferta que el operador acepta con [id] contra
/// `accept-pending`. El backend sólo la devuelve cuando el correo del caller
/// está verificado; el cliente no re-decide esa condición. `role` viaja crudo
/// (set cerrado del backend: OWNER/ADMIN/SUPERVISOR/WORKER) — la presentación
/// lo humaniza.
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.role,
  });

  final String id;
  final String orgId;
  final String orgName;
  final String role;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingInvitation &&
        other.id == id &&
        other.orgId == orgId &&
        other.orgName == orgName &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, orgId, orgName, role);
}
