import 'dart:typed_data';

/// Puerto para compartir la media de un mensaje con otras apps (el "share
/// sheet" del sistema). Recibe los BYTES ya resueltos (la caché por `mediaRef`
/// es la fuente; la URL firmada sólo el respaldo de descarga): compartir
/// funciona offline igual que ver.
abstract interface class MediaSharer {
  /// Lanza [MediaShareException] si el sistema no pudo compartir.
  Future<void> share({required Uint8List bytes, required String filename});
}

/// La media no se pudo materializar o el share sheet del sistema falló.
class MediaShareException implements Exception {
  const MediaShareException(this.reason);

  final String reason;

  @override
  String toString() => 'MediaShareException: $reason';
}
