/// Un miembro de la organización activa (`GET /workspace/members`).
///
/// `id` es el id de la membership (no el del usuario): es la clave sobre la
/// que operan el cambio de rol y la baja de miembro. `emailVerified` distingue
/// a quien ya confirmó su correo de un alta pendiente. `role` viaja crudo del
/// set cerrado del backend (OWNER/ADMIN/SUPERVISOR/WORKER); la presentación lo
/// humaniza si quiere.
///
/// No incluye `org_id`: todos los miembros listados comparten la org activa,
/// así que el campo del wire es redundante y se descarta en el mapper.
class Member {
  const Member({
    required this.id,
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.role,
  });

  final String id;
  final String userId;
  final String email;
  final bool emailVerified;
  final String role;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member &&
        other.id == id &&
        other.userId == userId &&
        other.email == email &&
        other.emailVerified == emailVerified &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(id, userId, email, emailVerified, role);
}
