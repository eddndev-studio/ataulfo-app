import 'dart:typed_data';

import '../../domain/entities/media_asset.dart';
import 'media_byte_store.dart';
import 'media_thumbnail_loader.dart';

/// [MediaThumbnailLoader] con disciplina "descargar una vez": consulta el
/// [MediaByteStore] por `ref` y sólo va a la red en un miss.
///
/// El orden importa:
/// 1. Hit en disco ⇒ sirve los bytes locales e **ignora `previewUrl`**. Esto da
///    dos cosas gratis: funciona offline y se desacopla del TTL de la firma (la
///    `previewUrl` pudo expirar, pero los bytes de un ref son inmutables).
/// 2. Miss con `previewUrl` ⇒ descarga, persiste por `ref` y devuelve los bytes.
/// 3. Miss sin `previewUrl`, o descarga fallida ⇒ `null` (placeholder). En el
///    fallo NO se escribe nada: un cache vacío vuelve a intentar; uno con basura
///    serviría una miniatura rota para siempre.
class CachingMediaThumbnailLoader implements MediaThumbnailLoader {
  CachingMediaThumbnailLoader({
    required MediaByteStore store,
    required Future<Uint8List?> Function(String url) download,
  }) : _store = store,
       _download = download;

  final MediaByteStore _store;
  final Future<Uint8List?> Function(String url) _download;

  @override
  Future<Uint8List?> load(MediaAsset asset) async {
    final cached = await _store.read(asset.ref);
    if (cached != null) return cached;

    final url = asset.previewUrl;
    if (url == null) return null;

    final bytes = await _download(url);
    if (bytes == null) return null;

    await _store.write(asset.ref, bytes);
    return bytes;
  }
}
