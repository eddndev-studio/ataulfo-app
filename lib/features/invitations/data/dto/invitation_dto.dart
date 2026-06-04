/// DTO del wire de `GET /workspace/invitations` (y la fila que devuelve el
/// POST de creación). Claves snake_case; timestamps RFC3339 UTC (sufijo Z) que
/// se parsean a `DateTime` UTC. `org_id` viaja pero es redundante y se descarta.
class InvitationResp {
  const InvitationResp({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory InvitationResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final role = json['role'];
    final status = json['status'];
    final expiresAt = json['expires_at'];
    final createdAt = json['created_at'];
    if (id is! String ||
        email is! String ||
        role is! String ||
        status is! String ||
        expiresAt is! String ||
        createdAt is! String) {
      throw const FormatException('invitationResp: clave obligatoria ausente');
    }
    // DateTime.parse de un timestamp con sufijo Z preserva el instante UTC; un
    // valor no parseable lanza FormatException, que el datasource colapsa.
    return InvitationResp(
      id: id,
      email: email,
      role: role,
      status: status,
      expiresAt: DateTime.parse(expiresAt),
      createdAt: DateTime.parse(createdAt),
    );
  }

  final String id;
  final String email;
  final String role;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
}
