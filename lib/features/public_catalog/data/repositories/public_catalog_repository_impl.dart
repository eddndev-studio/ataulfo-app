import '../../domain/entities/public_catalog_settings.dart';
import '../../domain/repositories/public_catalog_repository.dart';
import '../datasources/public_catalog_datasource.dart';

/// Implementación sobre el datasource HTTP. Passthrough: el datasource ya
/// entrega entidades de dominio y fallas tipadas.
class PublicCatalogRepositoryImpl implements PublicCatalogRepository {
  const PublicCatalogRepositoryImpl({required this.datasource});

  final PublicCatalogDatasource datasource;

  @override
  Future<PublicCatalogSettings> get() => datasource.get();

  @override
  Future<PublicCatalogSettings> update({
    required bool enabled,
    required String slug,
  }) => datasource.update(enabled: enabled, slug: slug);
}
