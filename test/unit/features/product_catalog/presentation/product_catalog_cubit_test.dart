import 'dart:async';

import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/product_catalog_failure.dart';
import 'package:ataulfo/features/product_catalog/domain/repositories/product_catalog_repository.dart';
import 'package:ataulfo/features/product_catalog/presentation/bloc/product_catalog_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ProductCatalogRepository {}

Product _p({
  String id = 'p1',
  ProductKind kind = ProductKind.product,
  String category = 'Fruta',
}) => Product(
  id: id,
  kind: kind,
  name: 'Mango',
  description: '',
  category: category,
  priceCents: 0,
  priceDisplay: '',
  mediaRef: '',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  setUpAll(() => registerFallbackValue(ProductKind.product));

  late _MockRepo repo;

  _MockRepo happyRepo() {
    repo = _MockRepo();
    when(() => repo.listProducts()).thenAnswer((_) async => <Product>[_p()]);
    when(repo.listCategories).thenAnswer((_) async => <String>['Fruta']);
    return repo;
  }

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'load ok ⇒ [loading, loaded(items+categorías)]',
    build: () => ProductCatalogCubit(happyRepo()),
    act: (c) => c.load(),
    // Tres estados: loading, las categorías que llegan primero (best-effort
    // en paralelo) y el loaded con los productos.
    expect: () => <Matcher>[
      isA<ProductCatalogState>().having(
        (s) => s.status,
        's',
        ProductCatalogStatus.loading,
      ),
      isA<ProductCatalogState>()
          .having((s) => s.status, 's', ProductCatalogStatus.loading)
          .having((s) => s.categories, 'categories', <String>['Fruta']),
      isA<ProductCatalogState>()
          .having((s) => s.status, 's', ProductCatalogStatus.loaded)
          .having((s) => s.items, 'items', hasLength(1))
          .having((s) => s.categories, 'categories', <String>['Fruta']),
    ],
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'load con productos rotos ⇒ error con el failure',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.listProducts(),
      ).thenThrow(const ProductCatalogServerFailure());
      when(repo.listCategories).thenAnswer((_) async => <String>[]);
      return ProductCatalogCubit(repo);
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<ProductCatalogState>().having(
        (s) => s.status,
        's',
        ProductCatalogStatus.loading,
      ),
      isA<ProductCatalogState>()
          .having((s) => s.status, 's', ProductCatalogStatus.error)
          .having((s) => s.failure, 'f', isA<ProductCatalogServerFailure>()),
    ],
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'load con categorías rotas ⇒ loaded igualmente (chips best-effort)',
    build: () {
      final repo = _MockRepo();
      when(() => repo.listProducts()).thenAnswer((_) async => <Product>[_p()]);
      when(repo.listCategories).thenThrow(const ProductCatalogNetworkFailure());
      return ProductCatalogCubit(repo);
    },
    act: (c) => c.load(),
    verify: (c) {
      expect(c.state.status, ProductCatalogStatus.loaded);
      expect(c.state.categories, isEmpty);
      expect(c.state.items, hasLength(1));
    },
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'setQuery no vacío ⇒ busca contra /search; vacío ⇒ vuelve al listado',
    build: () {
      final repo = happyRepo();
      when(
        () => repo.searchProducts(query: any(named: 'query')),
      ).thenAnswer((_) async => <Product>[_p(id: 'p2')]);
      return ProductCatalogCubit(repo);
    },
    act: (c) async {
      await c.load();
      await c.setQuery('mango');
      expect(c.state.items.single.id, 'p2');
      await c.setQuery('');
      expect(c.state.items.single.id, 'p1');
    },
    verify: (c) {
      expect(c.state.query, '');
    },
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'chips de categoría/kind filtran client-side sin refetch',
    build: () {
      repo = _MockRepo();
      when(() => repo.listProducts()).thenAnswer(
        (_) async => <Product>[
          _p(id: 'p1', category: 'Fruta'),
          _p(id: 'p2', category: 'Servicios', kind: ProductKind.service),
        ],
      );
      when(
        repo.listCategories,
      ).thenAnswer((_) async => <String>['Fruta', 'Servicios']);
      return ProductCatalogCubit(repo);
    },
    act: (c) async {
      await c.load();
      c.setCategory('Servicios');
      expect(c.state.visible.single.id, 'p2');
      c.setKind(ProductKind.product);
      expect(c.state.visible, isEmpty);
      c.setCategory(null);
      expect(c.state.visible.single.id, 'p1');
      c.setKind(null);
      expect(c.state.visible, hasLength(2));
    },
    verify: (c) {
      // Un solo fetch: los chips no vuelven a la red.
      verify(() => repo.listProducts()).called(1);
    },
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'create ok ⇒ null, recarga lista y categorías',
    build: () {
      final repo = happyRepo();
      when(
        () => repo.createProduct(
          kind: any(named: 'kind'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          category: any(named: 'category'),
          priceCents: any(named: 'priceCents'),
          mediaRef: any(named: 'mediaRef'),
          active: any(named: 'active'),
        ),
      ).thenAnswer((_) async => 'p9');
      return ProductCatalogCubit(repo);
    },
    act: (c) async {
      await c.load();
      final f = await c.create(
        kind: ProductKind.product,
        name: 'Nuevo',
        description: '',
        category: 'Fruta',
        priceCents: 100,
        mediaRef: '',
        active: true,
      );
      expect(f, isNull);
    },
    verify: (c) {
      expect(c.state.mutating, isFalse);
      // load inicial + recarga tras crear.
      verify(() => repo.listProducts()).called(2);
      verify(repo.listCategories).called(2);
    },
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'update con 422 ⇒ devuelve la Validation y no recarga',
    build: () {
      final repo = happyRepo();
      when(
        () => repo.updateProduct(
          id: any(named: 'id'),
          kind: any(named: 'kind'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          category: any(named: 'category'),
          priceCents: any(named: 'priceCents'),
          mediaRef: any(named: 'mediaRef'),
          active: any(named: 'active'),
        ),
      ).thenThrow(const ProductCatalogValidationFailure('inválido'));
      return ProductCatalogCubit(repo);
    },
    act: (c) async {
      await c.load();
      final f = await c.update(
        id: 'p1',
        kind: ProductKind.product,
        name: '',
        description: '',
        category: '',
        priceCents: 0,
        mediaRef: '',
        active: true,
      );
      expect(
        f,
        isA<ProductCatalogValidationFailure>().having(
          (e) => e.message,
          'm',
          'inválido',
        ),
      );
    },
    verify: (c) {
      expect(c.state.mutating, isFalse);
      // Solo el load inicial: el 422 no dispara recarga.
      verify(() => repo.listProducts()).called(1);
    },
  );

  blocTest<ProductCatalogCubit, ProductCatalogState>(
    'respuesta vieja de búsqueda no pisa a la nueva (guard de secuencia)',
    build: () {
      final repo = happyRepo();
      final slow = Completer<List<Product>>();
      when(
        () => repo.searchProducts(query: 'lento'),
      ).thenAnswer((_) => slow.future);
      when(
        () => repo.searchProducts(query: 'rapido'),
      ).thenAnswer((_) async => <Product>[_p(id: 'nuevo')]);
      // La búsqueda vieja resuelve DESPUÉS de que la nueva ya pintó.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        slow.complete(<Product>[_p(id: 'viejo')]);
      });
      return ProductCatalogCubit(repo);
    },
    act: (c) async {
      await c.load();
      final first = c.setQuery('lento');
      await c.setQuery('rapido');
      await first;
      expect(c.state.items.single.id, 'nuevo');
    },
  );
}
