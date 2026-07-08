import 'package:ataulfo/features/product_catalog/data/datasources/product_catalog_datasource.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/domain/failures/product_catalog_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> _productJson({String id = 'p1'}) => <String, dynamic>{
  'id': id,
  'kind': 'PRODUCT',
  'name': 'Mango Ataulfo',
  'description': 'Caja de 5 kg',
  'category': 'Fruta',
  'priceCents': 125000,
  'priceDisplay': r'$1,250.00 MXN',
  'mediaRef': '',
  'active': true,
  'createdAt': '2026-07-01T00:00:00Z',
  'updatedAt': '2026-07-02T00:00:00Z',
};

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioProductCatalogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioProductCatalogDatasource(dio);
  });

  Response<T> resp<T>(int status, {T? body}) => Response<T>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {dynamic data}) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );

  DioException byType(DioExceptionType type) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
  );

  // Stubs de verbo tipados (mocktail exige el mismo genérico que la llamada).
  void whenGet(Map<String, dynamic>? data, {int status = 200}) {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => resp<Map<String, dynamic>>(status, body: data));
  }

  (String, Map<String, dynamic>?) capturedGet() {
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
      ),
    ).captured;
    return (captured[0] as String, captured[1] as Map<String, dynamic>?);
  }

  group('listProducts', () {
    test(
      '200 ⇒ productos mapeados; sin filtros no viaja ningún param',
      () async {
        whenGet(<String, dynamic>{
          'products': <dynamic>[_productJson()],
        });
        final list = await ds.listProducts();
        expect(list, hasLength(1));
        expect(list.first.name, 'Mango Ataulfo');
        expect(list.first.kind, ProductKind.product);
        final (path, query) = capturedGet();
        expect(path, '/workspace/catalog/products');
        expect(query, anyOf(isNull, isEmpty));
      },
    );

    test(
      'filtros presentes ⇒ category/kind wire/activeOnly en la query',
      () async {
        whenGet(<String, dynamic>{'products': <dynamic>[]});
        await ds.listProducts(
          category: 'Fruta',
          kind: ProductKind.service,
          activeOnly: true,
        );
        final (_, query) = capturedGet();
        expect(query?['category'], 'Fruta');
        expect(query?['kind'], 'SERVICE');
        expect(query?['activeOnly'], 'true');
      },
    );

    test('producto malformado ⇒ UnknownProductCatalogFailure', () async {
      whenGet(<String, dynamic>{
        'products': <dynamic>[
          <String, dynamic>{'id': 'p1'},
        ],
      });
      await expectLater(
        ds.listProducts(),
        throwsA(isA<UnknownProductCatalogFailure>()),
      );
    });
  });

  group('listCategories', () {
    test('200 ⇒ lista de categorías', () async {
      whenGet(<String, dynamic>{
        'categories': <dynamic>['Fruta', 'Servicios'],
      });
      final cats = await ds.listCategories();
      expect(cats, <String>['Fruta', 'Servicios']);
      final (path, _) = capturedGet();
      expect(path, '/workspace/catalog/categories');
    });
  });

  group('searchProducts', () {
    test('envía q (+activeOnly/limit) y parsea productos', () async {
      whenGet(<String, dynamic>{
        'products': <dynamic>[_productJson()],
      });
      final list = await ds.searchProducts(
        query: 'mango',
        activeOnly: true,
        limit: 10,
      );
      expect(list.single.id, 'p1');
      final (path, query) = capturedGet();
      expect(path, '/workspace/catalog/search');
      expect(query?['q'], 'mango');
      expect(query?['activeOnly'], 'true');
      expect(query?['limit'], '10');
    });

    test('sin opcionales ⇒ solo viaja q', () async {
      whenGet(<String, dynamic>{'products': <dynamic>[]});
      await ds.searchProducts(query: 'mango');
      final (_, query) = capturedGet();
      expect(query?.keys, <String>['q']);
    });
  });

  group('createProduct', () {
    void whenPost({
      int status = 201,
      Map<String, dynamic>? body,
      DioException? err,
    }) {
      final stub = when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      );
      if (err != null) {
        stub.thenThrow(err);
      } else {
        stub.thenAnswer(
          (_) async => resp<Map<String, dynamic>>(status, body: body),
        );
      }
    }

    Future<String> create() => ds.createProduct(
      kind: ProductKind.service,
      name: 'Asesoría',
      description: 'Una hora',
      category: 'Servicios',
      priceCents: 50000,
      mediaRef: 'tenant/org/media/m1.png',
      active: true,
    );

    test(
      '201 ⇒ id; el body lleva el kind del wire y todos los campos',
      () async {
        whenPost(body: <String, dynamic>{'id': 'p9'});
        expect(await create(), 'p9');
        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          ),
        ).captured;
        expect(captured[0], '/workspace/catalog/products');
        final data = captured[1] as Map<String, dynamic>;
        expect(data['kind'], 'SERVICE');
        expect(data['name'], 'Asesoría');
        expect(data['description'], 'Una hora');
        expect(data['category'], 'Servicios');
        expect(data['priceCents'], 50000);
        expect(data['mediaRef'], 'tenant/org/media/m1.png');
        expect(data['active'], true);
      },
    );

    test('422 con código conocido ⇒ Validation con copy es-MX', () async {
      const cases = <String, String>{
        'invalid_product': 'Los datos del producto no son válidos.',
        'media_not_found': 'La imagen elegida ya no está en la galería.',
      };
      for (final entry in cases.entries) {
        whenPost(
          err: badResponse(422, data: <String, dynamic>{'error': entry.key}),
        );
        await expectLater(
          create(),
          throwsA(
            isA<ProductCatalogValidationFailure>().having(
              (f) => f.message,
              'message',
              entry.value,
            ),
          ),
          reason: 'código ${entry.key}',
        );
      }
    });

    test('422 con código desconocido ⇒ Validation SIN mensaje (jamás muestra '
        'el código wire crudo)', () async {
      whenPost(
        err: badResponse(422, data: <String, dynamic>{'error': 'algo_nuevo'}),
      );
      await expectLater(
        create(),
        throwsA(
          isA<ProductCatalogValidationFailure>().having(
            (f) => f.message,
            'message',
            isNull,
          ),
        ),
      );
    });

    test('403 ⇒ ProductCatalogForbiddenFailure', () async {
      whenPost(err: badResponse(403));
      await expectLater(
        create(),
        throwsA(isA<ProductCatalogForbiddenFailure>()),
      );
    });
  });

  group('updateProduct', () {
    test('204 ⇒ sin error; PUT al path con id y body completo', () async {
      when(
        () => dio.put<dynamic>(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => resp<dynamic>(204));
      await ds.updateProduct(
        id: 'p1',
        kind: ProductKind.product,
        name: 'Mango',
        description: '',
        category: '',
        priceCents: 0,
        mediaRef: '',
        active: false,
      );
      final captured = verify(
        () => dio.put<dynamic>(captureAny(), data: captureAny(named: 'data')),
      ).captured;
      expect(captured[0], '/workspace/catalog/products/p1');
      final data = captured[1] as Map;
      expect(data['kind'], 'PRODUCT');
      expect(data['priceCents'], 0);
      expect(data['active'], false);
    });

    test('404 ⇒ ProductCatalogNotFoundFailure', () async {
      when(
        () => dio.put<dynamic>(any(), data: any(named: 'data')),
      ).thenThrow(badResponse(404));
      await expectLater(
        ds.updateProduct(
          id: 'nope',
          kind: ProductKind.product,
          name: 'X',
          description: '',
          category: '',
          priceCents: 0,
          mediaRef: '',
          active: true,
        ),
        throwsA(isA<ProductCatalogNotFoundFailure>()),
      );
    });
  });

  group('mapeo genérico de DioException (vía listProducts)', () {
    void whenGetThrows(DioException e) {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(e);
    }

    test('timeouts ⇒ ProductCatalogTimeoutFailure', () async {
      for (final t in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        whenGetThrows(byType(t));
        await expectLater(
          ds.listProducts(),
          throwsA(isA<ProductCatalogTimeoutFailure>()),
        );
      }
    });

    test('connectionError ⇒ ProductCatalogNetworkFailure', () async {
      whenGetThrows(byType(DioExceptionType.connectionError));
      await expectLater(
        ds.listProducts(),
        throwsA(isA<ProductCatalogNetworkFailure>()),
      );
    });

    test('500 ⇒ ProductCatalogServerFailure', () async {
      whenGetThrows(badResponse(500));
      await expectLater(
        ds.listProducts(),
        throwsA(isA<ProductCatalogServerFailure>()),
      );
    });

    test(
      '400 bad_request (no contemplado) ⇒ UnknownProductCatalogFailure',
      () async {
        whenGetThrows(
          badResponse(400, data: <String, dynamic>{'error': 'bad_request'}),
        );
        await expectLater(
          ds.listProducts(),
          throwsA(isA<UnknownProductCatalogFailure>()),
        );
      },
    );
  });
}
