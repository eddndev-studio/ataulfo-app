import 'package:ataulfo/features/ai_catalog/data/datasources/catalog_datasource.dart';
import 'package:ataulfo/features/ai_catalog/domain/failures/catalog_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioCatalogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioCatalogDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/ai/catalog'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/ai/catalog'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/ai/catalog'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> catalogBody() => <String, dynamic>{
    'providers': <dynamic>[
      <String, dynamic>{
        'provider': 'GEMINI',
        'defaultModel': 'gemini-3.1-pro-preview',
        'models': <dynamic>[
          <String, dynamic>{
            'id': 'gemini-3.1-pro-preview',
            'supportsTemperature': true,
            'supportsThinking': true,
          },
          <String, dynamic>{
            'id': 'gemini-3.5-flash',
            'supportsTemperature': true,
            'supportsThinking': true,
          },
        ],
      },
      <String, dynamic>{
        'provider': 'OPENAI',
        'defaultModel': 'gpt-5.5',
        'models': <dynamic>[
          <String, dynamic>{
            'id': 'gpt-5.5',
            'supportsTemperature': false,
            'supportsThinking': true,
          },
        ],
      },
    ],
  };

  group('DioCatalogDatasource.fetch', () {
    test('200 con catalogResp → Catalog mapeado a entidades', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenAnswer((_) async => resp(200, body: catalogBody()));

      final catalog = await ds.fetch();

      expect(catalog.providers, hasLength(2));
      expect(catalog.providers[0].provider, 'GEMINI');
      expect(catalog.providers[0].defaultModel, 'gemini-3.1-pro-preview');
      expect(catalog.providers[0].models, hasLength(2));
      expect(catalog.providers[1].provider, 'OPENAI');
      expect(catalog.providers[1].models.first.supportsTemperature, isFalse);
      expect(catalog.providers[1].models.first.supportsThinking, isTrue);
    });

    test('timeout → CatalogTimeoutFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/ai/catalog')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/ai/catalog'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<CatalogTimeoutFailure>()),
      );
    });

    test('sin conexión → CatalogNetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/ai/catalog')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/ai/catalog'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<CatalogNetworkFailure>()),
      );
    });

    test('403 → CatalogForbiddenFailure', () async {
      // /ai/catalog viaja envuelto en adminOnly (misma pila que /templates).
      // WORKER/SUPERVISOR caen acá — la UI necesita distinguirlo del
      // genérico para mostrar copy útil.
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenThrow(badResponse(403));

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<CatalogForbiddenFailure>()),
      );
    });

    test('500 → CatalogServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenThrow(badResponse(500));

      await expectLater(() => ds.fetch(), throwsA(isA<CatalogServerFailure>()));
    });

    test('502 → CatalogServerFailure (cualquier 5xx)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenThrow(badResponse(502));

      await expectLater(() => ds.fetch(), throwsA(isA<CatalogServerFailure>()));
    });

    test('400 → UnknownCatalogFailure (status fuera del set)', () async {
      // El endpoint no emite 400 (read-only, sin body de request). Si llega,
      // el cliente lo expone como Unknown — no se asume nada del status.
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenThrow(badResponse(400));

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<UnknownCatalogFailure>()),
      );
    });

    test('body nulo → UnknownCatalogFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenAnswer((_) async => resp(200, body: null));

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<UnknownCatalogFailure>()),
      );
    });

    test('body malformado (sin providers) → UnknownCatalogFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/ai/catalog'),
      ).thenAnswer((_) async => resp(200, body: <String, dynamic>{}));

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<UnknownCatalogFailure>()),
      );
    });

    test('cancel → UnknownCatalogFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/ai/catalog')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/ai/catalog'),
          type: DioExceptionType.cancel,
        ),
      );

      await expectLater(
        () => ds.fetch(),
        throwsA(isA<UnknownCatalogFailure>()),
      );
    });
  });
}
