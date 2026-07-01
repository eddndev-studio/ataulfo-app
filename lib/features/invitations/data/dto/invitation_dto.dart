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
    this.token,
    this.emailSent = false,
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
    // `token` y `email_sent` sólo viajan en la respuesta de creación (201): el
    // token crudo es el secreto de un solo uso que el ADMIN comparte, y
    // email_sent dice si el correo salió. Ausentes en el listado ⇒ null/false.
    final token = json['token'];
    // DateTime.parse de un timestamp con sufijo Z preserva el instante UTC; un
    // valor no parseable lanza FormatException, que el datasource colapsa.
    return InvitationResp(
      id: id,
      email: email,
      role: role,
      status: status,
      expiresAt: DateTime.parse(expiresAt),
      createdAt: DateTime.parse(createdAt),
      token: token is String && token.isNotEmpty ? token : null,
      emailSent: json['email_sent'] == true,
    );
  }

  final String id;
  final String email;
  final String role;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Token crudo de la invitación — sólo en la respuesta de creación. Es el
  /// secreto que el ADMIN comparte out-of-band (WhatsApp) para que el invitado
  /// lo pegue al aceptar. Nunca viaja en el listado.
  final String? token;

  /// Si el backend logró enviar el correo de invitación. Sólo en creación.
  final bool emailSent;
}
