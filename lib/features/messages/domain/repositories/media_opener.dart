/// Puerto para abrir la media de un mensaje con una aplicación externa
/// (documentos, videos…): el equivalente al "abrir con" de mensajería.
/// El adaptador concreto descarga la URL firmada y delega al sistema.
abstract interface class MediaOpener {
  /// Lanza [MediaOpenException] si la descarga o la apertura fallan.
  Future<void> open({required String url});
}

/// La media no se pudo descargar o ninguna app del sistema pudo abrirla.
class MediaOpenException implements Exception {
  const MediaOpenException(this.reason);

  final String reason;

  @override
  String toString() => 'MediaOpenException: $reason';
}
