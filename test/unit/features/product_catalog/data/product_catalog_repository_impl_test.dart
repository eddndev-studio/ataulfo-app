import 'package:ataulfo/features/product_catalog/data/datasources/product_catalog_datasource.dart';
import 'package:ataulfo/features/product_catalog/data/repositories/product_catalog_repository_impl.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements ProductCatalogDatasource {}

final _product = Product(
  id: 'p1',
  kind: ProductKind.product,
  name: 'Mango',
  description: '',
  category: 'Fruta',
  priceCents: 0,
  priceDisplay: '',
  mediaRef: '',
  active: true,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  setUpAll(() => registerFallbackValue(ProductKind.product));

  late _MockDatasource ds;
  late ProductCatalogRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = ProductCatalogRepositoryImpl(datasource: ds);
  });

  test('delega listProducts con los filtros', () async {
    when(
      () => ds.listProducts(
        category: any(named: 'category'),
        kind: any(named: 'kind'),
        activeOnly: any(named: 'activeOnly'),
      ),
    ).thenAnswer((_) async => <Product>[_product]);
    final got = await repo.listProducts(
      category: 'Fruta',
      kind: ProductKind.product,
      activeOnly: true,
    );
    expect(got.single, _product);
    verify(
      () => ds.listProducts(
        category: 'Fruta',
        kind: ProductKind.product,
        activeOnly: true,
      ),
    ).called(1);
  });

  test('delega listCategories y searchProducts', () async {
    when(() => ds.listCategories()).thenAnswer((_) async => <String>['Fruta']);
    when(
      () => ds.searchProducts(
        query: any(named: 'query'),
        activeOnly: any(named: 'activeOnly'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <Product>[_product]);
    expect(await repo.listCategories(), <String>['Fruta']);
    expect(await repo.searchProducts(query: 'man'), hasLength(1));
    verify(() => ds.searchProducts(query: 'man')).called(1);
  });

  test('delega create/update con todos los campos', () async {
    when(
      () => ds.createProduct(
        kind: any(named: 'kind'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        category: any(named: 'category'),
        priceCents: any(named: 'priceCents'),
        mediaRef: any(named: 'mediaRef'),
        active: any(named: 'active'),
      ),
    ).thenAnswer((_) async => 'p9');
    when(
      () => ds.updateProduct(
        id: any(named: 'id'),
        kind: any(named: 'kind'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        category: any(named: 'category'),
        priceCents: any(named: 'priceCents'),
        mediaRef: any(named: 'mediaRef'),
        active: any(named: 'active'),
      ),
    ).thenAnswer((_) async {});

    final id = await repo.createProduct(
      kind: ProductKind.service,
      name: 'Asesoría',
      description: 'd',
      category: 'c',
      priceCents: 100,
      mediaRef: 'r',
      active: true,
    );
    expect(id, 'p9');
    await repo.updateProduct(
      id: 'p1',
      kind: ProductKind.product,
      name: 'X',
      description: '',
      category: '',
      priceCents: 0,
      mediaRef: '',
      active: false,
    );
    verify(
      () => ds.updateProduct(
        id: 'p1',
        kind: ProductKind.product,
        name: 'X',
        description: '',
        category: '',
        priceCents: 0,
        mediaRef: '',
        active: false,
      ),
    ).called(1);
  });
}
