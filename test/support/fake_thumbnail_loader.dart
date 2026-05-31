import 'dart:typed_data';

import 'package:ataulfo/features/media/domain/repositories/media_thumbnail_loader.dart';
import 'package:ataulfo/features/media/domain/entities/media_asset.dart';

/// Loader fake para tests de wiring/navegación: devuelve null (⇒ placeholder),
/// así las pruebas no dependen de red ni disco para pintar el grid. Los tests
/// que ejercitan la lógica de cache usan el `CachingMediaThumbnailLoader` real
/// con un `download` fake; éste es sólo para construir páginas/router.
class FakeThumbnailLoader implements MediaThumbnailLoader {
  const FakeThumbnailLoader();

  @override
  Future<Uint8List?> load(MediaAsset asset) async => null;
}
