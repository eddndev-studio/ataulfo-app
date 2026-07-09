import '../entities/catalog_appearance.dart';
import '../entities/public_catalog_settings.dart';

/// Repositorio de los ajustes del catálogo público de la org. Lanza
/// `PublicCatalogFailure` tipadas (el datasource ya tradujo el wire).
abstract interface class PublicCatalogRepository {
  Future<PublicCatalogSettings> get();
  Future<PublicCatalogSettings> update({
    required bool enabled,
    required String slug,
    required CatalogDesign design,
    required CatalogAccent accent,
  });
}
