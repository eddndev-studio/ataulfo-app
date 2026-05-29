/// Respuesta de `POST /bots/:id/connect-token` (201).
///
/// El backend emite el secreto crudo UNA sola vez (no se vuelve a recuperar)
/// junto con su caducidad. El datasource lo convierte en un [ConnectLink]
/// listo para compartir; el dominio no ve el token suelto.
class ConnectTokenResp {
  const ConnectTokenResp({required this.token, required this.expiresAt});

  factory ConnectTokenResp.fromJson(Map<String, dynamic> json) =>
      ConnectTokenResp(
        token: json['token'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final String token;
  final DateTime expiresAt;
}
