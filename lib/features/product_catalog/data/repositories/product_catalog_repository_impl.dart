import '../../domain/entities/product.dart';
import '../../domain/repositories/product_catalog_repository.dart';
import '../datasources/product_catalog_datasource.dart';

/// Delega en el datasource: no hay caché local del catálogo (es estado vivo
/// —otro admin puede editarlo entre lecturas—). Si una superficie necesitara
/// memoización, entra aquí sin tocar el puerto.
class ProductCatalogRepositoryImpl implements ProductCatalogRepository {
  ProductCatalogRepositoryImpl({required ProductCatalogDatasource datasource})
    : _ds = datasource;

  final ProductCatalogDatasource _ds;

  @override
  Future<List<Product>> listProducts({
    String? category,
    ProductKind? kind,
    bool activeOnly = false,
  }) =>
      _ds.listProducts(category: category, kind: kind, activeOnly: activeOnly);

  @override
  Future<List<String>> listCategories() => _ds.listCategories();

  @override
  Future<List<Product>> searchProducts({
    required String query,
    bool activeOnly = false,
    int? limit,
  }) => _ds.searchProducts(query: query, activeOnly: activeOnly, limit: limit);

  @override
  Future<String> createProduct({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => _ds.createProduct(
    kind: kind,
    name: name,
    description: description,
    category: category,
    priceCents: priceCents,
    mediaRef: mediaRef,
    active: active,
  );

  @override
  Future<void> updateProduct({
    required String id,
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => _ds.updateProduct(
    id: id,
    kind: kind,
    name: name,
    description: description,
    category: category,
    priceCents: priceCents,
    mediaRef: mediaRef,
    active: active,
  );
}
