import '../../domain/entities/catalog.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_datasource.dart';

/// Implementación trivial del puerto: la tabla se pide al backend en cada
/// `fetch()`. La tabla es estática del lado backend (no cambia por org ni
/// por usuario); si la UI necesita evitar refetches por sesión, una capa
/// de caché entra acá sin tocar el contrato del puerto.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required CatalogDatasource datasource})
    : _ds = datasource;

  final CatalogDatasource _ds;

  @override
  Future<Catalog> fetch() => _ds.fetch();
}
