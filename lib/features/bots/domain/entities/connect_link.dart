/// Enlace público de emparejamiento que el operador comparte con quien
/// sostiene el teléfono del WhatsApp a vincular.
///
/// Apunta a la página `/connect?token=` que el backend sirve directo: quien
/// la abre escanea el QR del bot sin tener cuenta. Es el lado-operador del
/// modelo de dos actores (S04): el operador autenticado emite el token; un
/// tercero anónimo escanea.
class ConnectLink {
  const ConnectLink({required this.url, required this.expiresAt});

  /// URL completa a compartir, p. ej. `https://host/connect?token=<raw>`.
  final String url;

  /// Caducidad del ConnectToken subyacente (TTL del backend). Pasada la
  /// fecha el enlace responde 410 y la página pide uno nuevo.
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is ConnectLink && other.url == url && other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(url, expiresAt);
}
