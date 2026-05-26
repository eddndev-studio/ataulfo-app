import '../entities/catalog.dart';

/// Puerto del repositorio del feature ai_catalog. La presentación depende
/// de esta interface, no del datasource: si en el futuro se cachea la
/// tabla en memoria/disco, la implementación orquesta verdad local vs.
/// remota sin reabrir el contrato.
abstract interface class CatalogRepository {
  /// Devuelve la tabla estática de proveedores y modelos del Motor IA.
  /// El backend no segmenta por org — todos los callers reciben el mismo
  /// catálogo.
  Future<Catalog> fetch();
}
