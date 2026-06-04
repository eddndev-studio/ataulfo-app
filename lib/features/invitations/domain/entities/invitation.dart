/// Una invitación de la organización activa (`GET /workspace/invitations`).
///
/// `status` viaja crudo del set cerrado del backend (PENDING/ACCEPTED/CANCELED).
/// El estado "expirada" NO existe en el wire: una invitación caducada sigue
/// PENDING hasta consumirse o cancelarse, así que se deriva en el cliente con
/// [isExpired]. No incluye `org_id`: todas comparten la org activa.
class Invitation {
  const Invitation({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// `true` si la invitación sigue PENDING pero su ventana ya pasó respecto a
  /// [now]. Sólo las PENDING expiran; ACCEPTED/CANCELED son terminales. [now]
  /// se inyecta para mantener la lógica pura y testeable; compara instantes
  /// (expiresAt llega UTC del wire, isAfter no depende de la zona de [now]).
  bool isExpired(DateTime now) => status == 'PENDING' && now.isAfter(expiresAt);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invitation &&
        other.id == id &&
        other.email == email &&
        other.role == role &&
        other.status == status &&
        other.expiresAt == expiresAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, email, role, status, expiresAt, createdAt);
}
