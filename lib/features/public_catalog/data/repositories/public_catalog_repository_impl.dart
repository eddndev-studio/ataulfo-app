import '../../domain/entities/catalog_appearance.dart';
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
    required CatalogDesign design,
    required CatalogAccent accent,
  }) => datasource.update(
    enabled: enabled,
    slug: slug,
    design: design,
    accent: accent,
  );
}
