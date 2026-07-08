import 'dart:typed_data';

import '../../media/data/cache/caching_media_thumbnail_loader.dart';
import '../../media/data/cache/dio_thumbnail_downloader.dart';
import '../../media/data/cache/file_media_byte_store.dart';
import '../../media/domain/entities/media_asset.dart';
import '../../media/domain/repositories/media_byte_store.dart';
import '../../media/domain/repositories/media_thumbnail_loader.dart';

/// Resuelve los bytes de la miniatura de un producto a partir de su
/// `mediaRef` BARE, reusando el MISMO cache en disco que la galería (los
/// bytes de un ref son inmutables y el namespace es compartido).
///
/// Dos caminos, según lo que se tenga a mano:
/// - con el [MediaAsset] efímero del picker (formulario recién elegido) ⇒ el
///   loader completo de la galería (cache y, en un miss, descarga de la URL
///   firmada del asset + persistencia);
/// - sólo el ref (producto hidratado del listado) ⇒ SOLO el cache: sin asset
///   no hay URL firmada y fabricarla localmente violaría el diseño. Un miss
///   cae al glifo — honesto: la miniatura aparece cuando la galería (o una
///   selección) la haya cacheado.
///
/// Nunca lanza: cualquier fallo (disco, plugin, red) es "sin miniatura"
/// (null). La URL firmada vive y muere dentro del loader; jamás sale de aquí.
class ProductThumbResolver {
  ProductThumbResolver({
    required MediaByteStore store,
    required MediaThumbnailLoader loader,
  }) : _store = store,
       _loader = loader;

  final MediaByteStore _store;
  final MediaThumbnailLoader _loader;

  /// Instancia de sesión con el cache real en disco. Vive aquí y no en el
  /// wiring central porque el árbol del catálogo no recibe el loader de la
  /// galería por constructor; el disco compartido (mismo namespace de bytes
  /// por ref) hace equivalentes ambas instancias. Los tests inyectan fakes.
  static final ProductThumbResolver session = () {
    final store = FileMediaByteStore();
    return ProductThumbResolver(
      store: store,
      loader: CachingMediaThumbnailLoader(
        store: store,
        download: DioThumbnailDownloader().call,
      ),
    );
  }();

  Future<Uint8List?> load(String ref, {MediaAsset? asset}) async {
    try {
      if (asset != null && asset.ref == ref) return await _loader.load(asset);
      return await _store.read(ref);
    } catch (_) {
      // Miniatura best-effort: sin bytes se pinta el glifo, nunca un error.
      return null;
    }
  }
}
