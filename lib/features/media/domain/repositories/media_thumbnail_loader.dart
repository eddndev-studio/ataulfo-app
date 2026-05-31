import 'dart:typed_data';

import '../entities/media_asset.dart';

/// Resuelve los bytes de la miniatura de un asset para pintarla. Abstrae al
/// widget de DÓNDE salen los bytes (cache en disco vs. red): el widget sólo
/// pide `load(asset)` y pinta lo que reciba, o cae al placeholder si es null.
abstract interface class MediaThumbnailLoader {
  /// Bytes para mostrar la miniatura de [asset], o `null` si no hay forma de
  /// obtenerlos (sin cache y sin `previewUrl`, o la descarga falló) — el
  /// consumidor cae a un placeholder.
  Future<Uint8List?> load(MediaAsset asset);
}
