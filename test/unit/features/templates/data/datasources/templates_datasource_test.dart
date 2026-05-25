import 'package:agentic/features/templates/data/datasources/templates_datasource.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/failures/templates_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioTemplatesDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioTemplatesDatasource(dio);
  });

  Response<List<dynamic>> resp(int status, {List<dynamic>? body}) =>
      Response<List<dynamic>>(
        requestOptions: RequestOptions(path: '/templates'),
        statusCode: status,
        data: body,
      );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/templates'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/templates'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> aiJson({
    String provider = 'GEMINI',
    String model = 'gemini-3.1-pro-preview',
    String thinkingLevel = 'LOW',
  }) => <String, dynamic>{
    'enabled': false,
    'provider': provider,
    'model': model,
    'temperature': 0.7,
    'thinking_level': thinkingLevel,
    'system_prompt': '',
    'context_messages': 20,
  };

  Map<String, dynamic> tplJson({
    String id = 't1',
    int version = 1,
    Map<String, dynamic>? ai,
  }) => <String, dynamic>{
    'id': id,
    'org_id': 'o1',
    'name': 'Soporte',
    'version': version,
    'ai': ai ?? aiJson(),
  };

  group('DioTemplatesDatasource.list', () {
    test('200 con [templateResp...] → List<Template>', () async {
      when(() => dio.get<List<dynamic>>('/templates')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            tplJson(),
            tplJson(
              id: 't2',
              version: 3,
              ai: aiJson(provider: 'OPENAI'),
            ),
          ],
        ),
      );

      final tpls = await ds.list();

      expect(tpls, hasLength(2));
      expect(tpls[0].id, 't1');
      expect(tpls[0].ai.provider, AIProvider.gemini);
      expect(tpls[1].id, 't2');
      expect(tpls[1].version, 3);
      expect(tpls[1].ai.provider, AIProvider.openai);
      verify(() => dio.get<List<dynamic>>('/templates')).called(1);
    });

    test('200 con [] → List<Template> vacía', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenAnswer((_) async => resp(200, body: <dynamic>[]));

      expect(await ds.list(), isEmpty);
    });

    test('timeout → TemplatesTimeoutFailure', () async {
      when(() => dio.get<List<dynamic>>('/templates')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<TemplatesTimeoutFailure>()));
    });

    test('sin conexión → TemplatesNetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/templates')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(ds.list(), throwsA(isA<TemplatesNetworkFailure>()));
    });

    test('403 → TemplatesForbiddenFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenThrow(badResponse(403));

      await expectLater(ds.list(), throwsA(isA<TemplatesForbiddenFailure>()));
    });

    test('500 → TemplatesServerFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenThrow(badResponse(500));

      await expectLater(ds.list(), throwsA(isA<TemplatesServerFailure>()));
    });

    test('503 → TemplatesServerFailure (cubre 5xx genérico)', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenThrow(badResponse(503));

      await expectLater(ds.list(), throwsA(isA<TemplatesServerFailure>()));
    });

    test('418 (no contemplado) → UnknownTemplatesFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenThrow(badResponse(418));

      await expectLater(ds.list(), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test('body nulo → UnknownTemplatesFailure (contrato roto)', () async {
      when(
        () => dio.get<List<dynamic>>('/templates'),
      ).thenAnswer((_) async => resp(200));

      await expectLater(ds.list(), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test('body con elemento malformado → UnknownTemplatesFailure', () async {
      when(() => dio.get<List<dynamic>>('/templates')).thenAnswer(
        (_) async => resp(
          200,
          body: <dynamic>[
            <String, dynamic>{'id': 'x'}, // faltan claves
          ],
        ),
      );

      await expectLater(ds.list(), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test(
      'proveedor desconocido en el wire → ArgumentError (fail-loud)',
      () async {
        // Drift de contrato del backend: si introduce un proveedor nuevo sin
        // que el cliente lo conozca, el mapper rompe en boot. NO se traduce
        // a UnknownTemplatesFailure porque el operador no puede reintentar
        // su salida — es un bug que debe enterarse el desarrollador.
        when(() => dio.get<List<dynamic>>('/templates')).thenAnswer(
          (_) async => resp(
            200,
            body: <dynamic>[tplJson(ai: aiJson(provider: 'ANTHROPIC'))],
          ),
        );

        await expectLater(ds.list(), throwsArgumentError);
      },
    );
  });
}
