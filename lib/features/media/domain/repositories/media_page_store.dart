import '../entities/media_asset.dart';

/// Almacén local de la PRIMERA página del catálogo, namespaceada por
/// `(orgId, type)`. Da persistencia y offline al cache de la galería: tras un
/// reinicio o sin red, la última página conocida de la org se sirve desde aquí.
///
/// El namespacing por `orgId` es la frontera multitenant en disco: la metadata
/// de una org jamás se sirve a otra aunque el logout no haya alcanzado a purgar.
/// El `type` (null|image|video|audio|document) separa la galería completa de
/// cada picker filtrado, igual que el cache en memoria.
abstract interface class MediaPageStore {
  /// Página persistida para `(orgId, type)`, o `null` si no hay (o está
  /// corrupta — se trata como miss, nunca lanza).
  Future<MediaPage?> read(String orgId, String? type);

  /// Persiste [page] para `(orgId, type)` (sobrescribe).
  Future<void> write(String orgId, String? type, MediaPage page);

  /// Borra TODO lo persistido (todas las orgs y tipos). Lo invoca el purgado de
  /// sesión (logout) y la invalidación de frescura.
  Future<void> clear();
}
