import 'package:dio/dio.dart';

import '../../domain/entities/product.dart';
import '../../domain/failures/product_catalog_failure.dart';
import '../dto/product_dto.dart';
import '../mappers/product_mapper.dart';

/// Puerto de datos del catálogo de productos. Las implementaciones lanzan
/// `ProductCatalogFailure` tipadas; nunca DioException cruda.
abstract interface class ProductCatalogDatasource {
  Future<List<Product>> listProducts({
    String? category,
    ProductKind? kind,
    bool activeOnly = false,
  });
  Future<List<String>> listCategories();
  Future<List<Product>> searchProducts({
    required String query,
    bool activeOnly = false,
    int? limit,
  });
  Future<String> createProduct({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  });
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

class DioProductCatalogDatasource implements ProductCatalogDatasource {
  DioProductCatalogDatasource(this._dio);

  final Dio _dio;

  static const String _base = '/workspace/catalog';

  @override
  Future<List<Product>> listProducts({
    String? category,
    ProductKind? kind,
    bool activeOnly = false,
  }) => _guardRead(() async {
    // Solo viajan los filtros presentes: para el backend un param vacío
    // no filtra, pero omitirlo mantiene la query canónica.
    final query = <String, dynamic>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (kind != null) 'kind': ProductMapper.kindToWire(kind),
      if (activeOnly) 'activeOnly': 'true',
    };
    final body = await _getMap(
      '$_base/products',
      query: query.isEmpty ? null : query,
    );
    return _parseProducts(body);
  });

  @override
  Future<List<String>> listCategories() => _guardRead(() async {
    final body = await _getMap('$_base/categories');
    return (body['categories'] as List<dynamic>).cast<String>().toList(
      growable: false,
    );
  });

  @override
  Future<List<Product>> searchProducts({
    required String query,
    bool activeOnly = false,
    int? limit,
  }) => _guardRead(() async {
    final body = await _getMap(
      '$_base/search',
      query: <String, dynamic>{
        'q': query,
        if (activeOnly) 'activeOnly': 'true',
        if (limit != null) 'limit': '$limit',
      },
    );
    return _parseProducts(body);
  });

  @override
  Future<String> createProduct({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => _guardMutation(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/products',
      data: _productBody(
        kind: kind,
        name: name,
        description: description,
        category: category,
        priceCents: priceCents,
        mediaRef: mediaRef,
        active: active,
      ),
    );
    final id = res.data?['id'];
    if (id is! String) throw const FormatException('respuesta sin id');
    return id;
  });

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
  }) => _guardMutation(() async {
    await _dio.put<dynamic>(
      '$_base/products/$id',
      data: _productBody(
        kind: kind,
        name: name,
        description: description,
        category: category,
        priceCents: priceCents,
        mediaRef: mediaRef,
        active: active,
      ),
    );
  });

  // ── Helpers de red ──────────────────────────────────────────────────────

  Map<String, dynamic> _productBody({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => <String, dynamic>{
    'kind': ProductMapper.kindToWire(kind),
    'name': name,
    'description': description,
    'category': category,
    'priceCents': priceCents,
    'mediaRef': mediaRef,
    'active': active,
  };

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return body;
  }

  List<Product> _parseProducts(Map<String, dynamic> body) =>
      (body['products'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductDto.fromJson)
          .map(ProductMapper.dtoToEntity)
          .toList(growable: false);

  // ── Traducción de errores ───────────────────────────────────────────────

  /// Envuelve una lectura: DioException/parse rotos ⇒ failure de lectura
  /// (sin 422 propio, que es de las mutaciones).
  Future<T> _guardRead<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on ProductCatalogFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownProductCatalogFailure();
    } on TypeError {
      throw const UnknownProductCatalogFailure();
    }
  }

  /// Envuelve una mutación: añade 422 (producto inválido / imagen fuera de la
  /// galería, con mensaje traducido) sobre el mapeo de lectura.
  Future<T> _guardMutation<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on ProductCatalogFailure {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode == 422) {
        throw ProductCatalogValidationFailure(
          _validationMessage(e.response?.data),
        );
      }
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownProductCatalogFailure();
    } on TypeError {
      throw const UnknownProductCatalogFailure();
    }
  }

  ProductCatalogFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ProductCatalogTimeoutFailure();
      case DioExceptionType.connectionError:
        return const ProductCatalogNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const ProductCatalogForbiddenFailure();
        if (status == 404) return const ProductCatalogNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const ProductCatalogServerFailure();
        }
        return const UnknownProductCatalogFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownProductCatalogFailure();
    }
  }

  /// Copy es-MX por código estable de rechazo 422 del backend
  /// (`{"error": code}`). El wire manda códigos, no frases: aquí es la única
  /// frontera que los conoce y los traduce. Un código fuera del mapa degrada
  /// a null (la UI cae a su copy genérico); JAMÁS se muestra el código crudo.
  static const Map<String, String> _validationCopy = <String, String>{
    'invalid_product': 'Los datos del producto no son válidos.',
    'media_not_found': 'La imagen elegida ya no está en la galería.',
  };

  String? _validationMessage(dynamic data) {
    if (data is! Map) return null;
    final code = data['error'];
    if (code is! String) return null;
    return _validationCopy[code];
  }
}
