import '../entities/product.dart';

/// Puerto del catálogo de productos: listado con filtros, categorías,
/// búsqueda difusa y CRUD. Las implementaciones lanzan
/// `ProductCatalogFailure` tipadas; nunca DioException cruda. El dominio no
/// conoce el transporte.
abstract interface class ProductCatalogRepository {
  /// `GET /workspace/catalog/products?category=&kind=&activeOnly=` — el
  /// catálogo de la org activa. Filtros ausentes no filtran. workerOnly:
  /// cualquier miembro lo lee.
  Future<List<Product>> listProducts({
    String? category,
    ProductKind? kind,
    bool activeOnly = false,
  });

  /// `GET /workspace/catalog/categories` — las categorías existentes,
  /// derivadas de los productos de la org.
  Future<List<String>> listCategories();

  /// `GET /workspace/catalog/search?q=&activeOnly=&limit=` — búsqueda difusa
  /// por nombre/descripción. El default y el tope del limit son del backend.
  Future<List<Product>> searchProducts({
    required String query,
    bool activeOnly = false,
    int? limit,
  });

  /// `POST /workspace/catalog/products` (ADMIN+). Devuelve el id del
  /// producto recién creado. 422 si es inválido o la imagen no existe.
  Future<String> createProduct({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  });

  /// `PUT /workspace/catalog/products/{id}` (ADMIN+). Reemplaza los campos
  /// editables del producto, incluido `active`.
  Future<void> updateProduct({
    required String id,
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  });
}
