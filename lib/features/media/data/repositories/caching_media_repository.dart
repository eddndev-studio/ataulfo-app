import 'dart:async';
import 'dart:typed_data';

import '../../domain/entities/media_asset.dart';
import '../../domain/failures/media_failure.dart';
import '../../domain/repositories/media_page_store.dart';
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
/// El default (3 min) está por debajo de la firma del backend (5 min): gobierna
/// cuándo la copia EN MEMORIA se considera fresca y se vuelve a la red.
///
/// Persistencia + offline (capa en disco opcional): si se inyecta un
/// [MediaPageStore] y un proveedor de `orgId`, cada lista online exitosa también
/// se persiste por `(orgId, type)`, y si la red falla se sirve la última página
/// persistida (stale) en vez de propagar el error. Servir metadata stale es
/// seguro AHORA porque las miniaturas con bytes ya cacheados se pintan ignorando
/// la `previewUrl` (que pudo expirar); las no cacheadas caen a placeholder. El
/// `orgId` namespacea el disco: la metadata de una org jamás se sirve a otra.
/// Sin store/orgId el decorador se comporta igual que sólo-en-memoria.
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
    MediaPageStore? store,
    String? Function()? orgId,
  }) : _ttl = ttl,
       _now = now,
       _store = store,
       _orgId = orgId;

  final MediaRepository _inner;
  final Duration _ttl;
  final DateTime Function() _now;

  /// Capa de persistencia opcional. Null ⇒ sólo cache en memoria.
  final MediaPageStore? _store;

  /// Proveedor del `orgId` activo (de los claims de auth). Null o devolviendo
  /// null ⇒ no se toca el disco (no se puede namespacear sin org).
  final String? Function()? _orgId;

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
  Future<void> delete(String ref) async {
    await _inner.delete(ref);
    // Tras un borrado exitoso, el asset desaparece de ALGUNA familia: limpiamos
    // todos los buckets (igual que upload). Un borrado que falló no cambió el
    // catálogo, así que propaga sin invalidar (no se llega a esta línea).
    invalidate();
  }

  @override
  Future<MediaPage> listAssets({String? cursor, int? limit, String? type}) {
    // Sólo la primera página se memoiza/persiste; las páginas profundas van a la
    // red (cachearlas desincronizaría la paginación) y jamás tocan el disco.
    if (cursor != null) {
      return _inner.listAssets(cursor: cursor, limit: limit, type: type);
    }
    final cached = _firstPageByType[type];
    if (cached != null && _now().difference(cached.at) < _ttl) {
      return Future<MediaPage>.value(cached.page);
    }
    return _loadFirstPage(limit, type);
  }

  /// Carga la primera página: red primero (memoiza + persiste en éxito); si la
  /// red falla, sirve la última página persistida (stale, offline) si existe.
  Future<MediaPage> _loadFirstPage(int? limit, String? type) async {
    final org = _orgId?.call();
    try {
      final page = await _inner.listAssets(
        cursor: null,
        limit: limit,
        type: type,
      );
      _firstPageByType[type] = _CachedPage(page, _now());
      if (_store != null && org != null) {
        // Persistencia best-effort: un fallo de disco no rompe la lista online.
        try {
          await _store.write(org, type, page);
        } catch (_) {}
      }
      return page;
    } on MediaFailure {
      // Sólo un fallo del catálogo (red/server tipado) cae al disco. Un error
      // no-MediaFailure (bug del datasource: TypeError, StateError…) se propaga:
      // enmascararlo sirviendo stale escondería el bug.
      if (_store != null && org != null) {
        final persisted = await _store.read(org, type);
        // Stale a propósito: no se memoiza en L1 para que cada entrada reintente
        // la red y sólo caiga al disco mientras siga sin conexión.
        if (persisted != null) return persisted;
      }
      rethrow;
    }
  }

  @override
  void invalidate() {
    _firstPageByType.clear();
    // El disco se purga best-effort (fire-and-forget): logout y pull-to-refresh.
    // En refresh, la re-lista inmediata vuelve a escribir; un raro solape
    // clear↔write sólo deja de persistir esa ronda (la memoria no se afecta).
    unawaited(_store?.clear() ?? Future<void>.value());
  }
}

/// Primera página cacheada junto al instante en que se trajo, para medir el TTL.
class _CachedPage {
  const _CachedPage(this.page, this.at);

  final MediaPage page;
  final DateTime at;
}
