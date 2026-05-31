import 'dart:typed_data';

import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';

/// Decora un [MediaRepository] memoizando la PRIMERA página del catálogo por
/// familia `type`. El bloc de la galería es page-scoped (nace y muere con cada
/// entrada), así que sin esto cada visita re-pide el catálogo aunque no haya
/// cambiado. Esta instancia se sostiene a nivel de sesión (singleton en la
/// composición), por eso el cache sobrevive a las entradas/salidas de la página.
///
/// Qué se cachea y qué no:
/// - Sólo `cursor == null` (la primera página). El load-more (cursor no-vacío)
///   se acumula en el estado del bloc y SIEMPRE delega: cachearlo desincronizaría
///   la paginación.
/// - La clave es la familia `type` (null|image|video|audio|document); cada
///   bucket es independiente, para que el picker filtrado no sirva de la galería
///   completa ni viceversa.
///
/// Frescura — un TTL acotado por la vida de las URLs firmadas del wire. La
/// página cacheada incluye `previewUrl` efímeras y NO existe endpoint para
/// re-firmar un ref suelto: la única forma de refrescarlas es re-listar. Servir
/// una página más vieja que la firma daría miniaturas rotas, por eso el TTL vive
/// por debajo de esa ventana. Al expirar, [listAssets] vuelve a la red (y trae
/// URLs frescas).
///
/// Invalidación:
/// - Las mutaciones que pasan por el repo se auto-invalidan: tras un [upload]
///   con éxito se limpian TODOS los buckets (el archivo subido cae en ALGUNA
///   familia, así que invalida la galería completa y cada picker filtrado, no
///   sólo el bucket desde el que se emitió).
/// - [invalidate] manual cubre lo que el repo no puede inferir: forzar frescura
///   (pull-to-refresh) y purgar al cerrar sesión (evita servir el catálogo de
///   una organización a la siguiente sin reiniciar la app).
class CachingMediaRepository implements MediaRepository {
  CachingMediaRepository(
    this._inner, {
    Duration ttl = const Duration(minutes: 3),
    DateTime Function() now = DateTime.now,
  }) : _ttl = ttl,
       _now = now;

  final MediaRepository _inner;
  final Duration _ttl;
  final DateTime Function() _now;

  final Map<String?, _CachedPage> _firstPageByType = <String?, _CachedPage>{};

  @override
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    final result = await _inner.upload(bytes: bytes, filename: filename);
    // Sólo invalidamos tras una subida exitosa: una que falló no cambió el
    // catálogo y el cache sigue siendo verdad.
    invalidate();
    return result;
  }

  @override
  Future<MediaPage> listAssets({String? cursor, int? limit, String? type}) {
    // Sólo la primera página se memoiza; las páginas profundas van a la red.
    if (cursor != null) {
      return _inner.listAssets(cursor: cursor, limit: limit, type: type);
    }
    final cached = _firstPageByType[type];
    if (cached != null && _now().difference(cached.at) < _ttl) {
      return Future<MediaPage>.value(cached.page);
    }
    return _inner.listAssets(cursor: cursor, limit: limit, type: type).then((
      page,
    ) {
      _firstPageByType[type] = _CachedPage(page, _now());
      return page;
    });
  }

  @override
  void invalidate() => _firstPageByType.clear();
}

/// Primera página cacheada junto al instante en que se trajo, para medir el TTL.
class _CachedPage {
  const _CachedPage(this.page, this.at);

  final MediaPage page;
  final DateTime at;
}
