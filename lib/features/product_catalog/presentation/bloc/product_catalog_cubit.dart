import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/product.dart';
import '../../domain/failures/product_catalog_failure.dart';
import '../../domain/repositories/product_catalog_repository.dart';

/// Listado, búsqueda y edición del catálogo de productos (Ajustes →
/// Catálogo). El buscador decide la fuente ([ProductCatalogState.query]
/// vacío ⇒ listado completo; con texto ⇒ búsqueda difusa del backend); los
/// chips de categoría/kind refinan client-side sobre ese resultado — el
/// catálogo de una org es corto y el refinado instantáneo evita un fetch y
/// sus carreras por cada tap.
///
/// Las mutaciones (crear/editar) recargan lista y categorías frescas del
/// backend: la vista nunca adivina el resultado de un POST/PUT. Devuelven la
/// falla al llamador para que el formulario decida (cerrarse o mostrar el
/// error) sin acoplar el cubit a la UI.
enum ProductCatalogStatus { loading, loaded, error }

class ProductCatalogState {
  const ProductCatalogState({
    required this.status,
    required this.items,
    required this.categories,
    required this.query,
    required this.category,
    required this.kind,
    required this.failure,
    required this.mutating,
  });

  const ProductCatalogState.loading()
    : status = ProductCatalogStatus.loading,
      items = const <Product>[],
      categories = const <String>[],
      query = '',
      category = null,
      kind = null,
      failure = null,
      mutating = false;

  final ProductCatalogStatus status;

  /// Resultado crudo del modo actual (listado completo o búsqueda). La vista
  /// pinta [visible], que aplica los chips encima.
  final List<Product> items;
  final List<String> categories;

  /// Texto vigente del buscador ('' = listado normal).
  final String query;

  /// Chip de categoría activo (null = todas).
  final String? category;

  /// Filtro de kind activo (null = ambos).
  final ProductKind? kind;
  final ProductCatalogFailure? failure;
  final bool mutating;

  /// Los items tras aplicar los chips de categoría/kind.
  List<Product> get visible => items
      .where((p) => category == null || p.category == category)
      .where((p) => kind == null || p.kind == kind)
      .toList(growable: false);

  ProductCatalogState copyWith({
    ProductCatalogStatus? status,
    List<Product>? items,
    List<String>? categories,
    String? query,
    String? category,
    bool clearCategory = false,
    ProductKind? kind,
    bool clearKind = false,
    ProductCatalogFailure? failure,
    bool clearFailure = false,
    bool? mutating,
  }) => ProductCatalogState(
    status: status ?? this.status,
    items: items ?? this.items,
    categories: categories ?? this.categories,
    query: query ?? this.query,
    category: clearCategory ? null : (category ?? this.category),
    kind: clearKind ? null : (kind ?? this.kind),
    failure: clearFailure ? null : (failure ?? this.failure),
    mutating: mutating ?? this.mutating,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductCatalogState &&
        other.status == status &&
        other.query == query &&
        other.category == category &&
        other.kind == kind &&
        other.failure == failure &&
        other.mutating == mutating &&
        _listEquals(other.items, items) &&
        _listEquals(other.categories, categories);
  }

  @override
  int get hashCode => Object.hash(
    status,
    query,
    category,
    kind,
    failure,
    mutating,
    Object.hashAll(items),
    Object.hashAll(categories),
  );
}

class ProductCatalogCubit extends Cubit<ProductCatalogState> {
  ProductCatalogCubit(this._repo) : super(const ProductCatalogState.loading());

  final ProductCatalogRepository _repo;

  /// Secuencia de fetch: cada refresh la avanza y solo la respuesta del
  /// último aplica. Sin esto, una búsqueda lenta que resuelve tarde pisaría
  /// a la vigente.
  int _seq = 0;

  Future<void> load() async {
    await Future.wait(<Future<void>>[_refreshCategories(), _refresh()]);
  }

  /// Fija el texto del buscador y re-consulta la fuente que toca. El
  /// debounce es de la vista; aquí cada llamada consulta.
  Future<void> setQuery(String query) async {
    final q = query.trim();
    if (q == state.query) return;
    emit(state.copyWith(query: q));
    await _refresh();
  }

  /// Chips: refinan [ProductCatalogState.visible] sin volver a la red.
  void setCategory(String? category) =>
      emit(state.copyWith(category: category, clearCategory: category == null));

  void setKind(ProductKind? kind) =>
      emit(state.copyWith(kind: kind, clearKind: kind == null));

  Future<ProductCatalogFailure?> create({
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => _mutate(
    () => _repo.createProduct(
      kind: kind,
      name: name,
      description: description,
      category: category,
      priceCents: priceCents,
      mediaRef: mediaRef,
      active: active,
    ),
  );

  Future<ProductCatalogFailure?> update({
    required String id,
    required ProductKind kind,
    required String name,
    required String description,
    required String category,
    required int priceCents,
    required String mediaRef,
    required bool active,
  }) => _mutate(
    () => _repo.updateProduct(
      id: id,
      kind: kind,
      name: name,
      description: description,
      category: category,
      priceCents: priceCents,
      mediaRef: mediaRef,
      active: active,
    ),
  );

  /// Re-consulta los items del modo vigente (listado o búsqueda) bajo el
  /// guard de secuencia.
  Future<void> _refresh() async {
    final seq = ++_seq;
    emit(
      state.copyWith(status: ProductCatalogStatus.loading, clearFailure: true),
    );
    try {
      final items = state.query.isEmpty
          ? await _repo.listProducts()
          : await _repo.searchProducts(query: state.query);
      if (seq != _seq || isClosed) return;
      emit(state.copyWith(status: ProductCatalogStatus.loaded, items: items));
    } on ProductCatalogFailure catch (f) {
      if (seq != _seq || isClosed) return;
      emit(state.copyWith(status: ProductCatalogStatus.error, failure: f));
    }
  }

  /// Categorías best-effort: alimentan chips y sugerencias del formulario;
  /// si fallan, la página vive sin ellas (se reintentan en la próxima
  /// mutación o load).
  Future<void> _refreshCategories() async {
    try {
      final categories = await _repo.listCategories();
      if (isClosed) return;
      emit(state.copyWith(categories: categories));
    } on ProductCatalogFailure {
      // Chips vacíos; el listado sigue siendo usable.
    }
  }

  Future<ProductCatalogFailure?> _mutate(Future<void> Function() op) async {
    if (state.mutating) return null;
    emit(state.copyWith(mutating: true));
    try {
      await op();
    } on ProductCatalogFailure catch (f) {
      emit(state.copyWith(mutating: false));
      return f;
    }
    emit(state.copyWith(mutating: false));
    await load();
    return null;
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
