import 'package:agentic/features/templates/data/datasources/templates_datasource.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/domain/entities/variable_def.dart';
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

  Response<Map<String, dynamic>> respMap(
    int status, {
    Map<String, dynamic>? body,
    String path = '/templates/t1',
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {String path = '/templates'}) =>
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
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

  group('DioTemplatesDatasource.create', () {
    test('201 con templateResp → Template (envía {name})', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => respMap(201, body: tplJson(), path: '/templates'),
      );

      final tpl = await ds.create('Soporte');

      expect(tpl.id, 't1');
      expect(tpl.name, 'Soporte');
      expect(tpl.ai.provider, AIProvider.gemini);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: <String, dynamic>{'name': 'Soporte'},
        ),
      ).called(1);
    });

    test('422 → TemplatesInvalidNameFailure', () async {
      // POST /templates devuelve 422 cuando el nombre viola la validación
      // del dominio (vacío, demasiado largo). El cliente lo distingue del
      // genérico para mostrar copy útil ("revisa el nombre").
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(422, path: '/templates'));

      await expectLater(
        ds.create(''),
        throwsA(isA<TemplatesInvalidNameFailure>()),
      );
    });

    test('403 → TemplatesForbiddenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(403, path: '/templates'));

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<TemplatesForbiddenFailure>()),
      );
    });

    test('500 → TemplatesServerFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(500, path: '/templates'));

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<TemplatesServerFailure>()),
      );
    });

    test('timeout → TemplatesTimeoutFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates'),
          type: DioExceptionType.sendTimeout,
        ),
      );

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<TemplatesTimeoutFailure>()),
      );
    });

    test('sin conexión → TemplatesNetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<TemplatesNetworkFailure>()),
      );
    });

    test('409 (sin org activa, caso raro) → UnknownTemplatesFailure', () async {
      // El handler devuelve 409 si el Bearer no trae org activa; en flujo
      // normal (post-login + /auth/me) esto no ocurre. Colapsa a Unknown
      // sin variante propia hasta que tengamos UI de switch-org.
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse(409, path: '/templates'));

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });

    test('body nulo → UnknownTemplatesFailure (contrato roto)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => respMap(201, path: '/templates'));

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });

    test('body malformado → UnknownTemplatesFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/templates',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => respMap(
          201,
          body: <String, dynamic>{'id': 'x'},
          path: '/templates',
        ),
      );

      await expectLater(
        ds.create('Soporte'),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });
  });

  group('DioTemplatesDatasource.listVarDefs', () {
    Map<String, dynamic> varDefJson({
      String id = 'v1',
      String name = 'nombre',
      String type = 'text',
      String def = '',
      String description = '',
    }) => <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'default': def,
      'description': description,
    };

    test('200 con {version, defs[]} → List<VariableDef>', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{
            'version': 3,
            'defs': <dynamic>[
              varDefJson(name: 'nombre', def: 'cliente'),
              varDefJson(id: 'v2', name: 'edad', def: '0'),
            ],
          },
          path: '/templates/t1/variable-definitions',
        ),
      );

      final defs = await ds.listVarDefs('t1');

      expect(defs, hasLength(2));
      expect(defs[0].name, 'nombre');
      expect(defs[0].defaultValue, 'cliente');
      expect(defs[0].type, VarType.text);
      expect(defs[1].name, 'edad');
    });

    test(
      '200 con defs vacío → lista vacía (plantilla sin variables)',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>(
            '/templates/t1/variable-definitions',
          ),
        ).thenAnswer(
          (_) async => respMap(
            200,
            body: <String, dynamic>{'version': 1, 'defs': <dynamic>[]},
            path: '/templates/t1/variable-definitions',
          ),
        );

        expect(await ds.listVarDefs('t1'), isEmpty);
      },
    );

    test(
      '404 → TemplatesNotFoundFailure (plantilla padre no existe)',
      () async {
        // El backend devuelve 404 si la plantilla del path no existe en la
        // org. Reusa el mismo mapping que /templates/:id.
        when(
          () => dio.get<Map<String, dynamic>>(
            '/templates/desconocido/variable-definitions',
          ),
        ).thenThrow(
          badResponse(404, path: '/templates/desconocido/variable-definitions'),
        );

        await expectLater(
          ds.listVarDefs('desconocido'),
          throwsA(isA<TemplatesNotFoundFailure>()),
        );
      },
    );

    test('403 → TemplatesForbiddenFailure', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenThrow(badResponse(403, path: '/templates/t1/variable-definitions'));

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<TemplatesForbiddenFailure>()),
      );
    });

    test('5xx → TemplatesServerFailure', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenThrow(badResponse(503, path: '/templates/t1/variable-definitions'));

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<TemplatesServerFailure>()),
      );
    });

    test('timeout → TemplatesTimeoutFailure', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/templates/t1/variable-definitions',
          ),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<TemplatesTimeoutFailure>()),
      );
    });

    test('sin conexión → TemplatesNetworkFailure', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/templates/t1/variable-definitions',
          ),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<TemplatesNetworkFailure>()),
      );
    });

    test('body nulo → UnknownTemplatesFailure (contrato roto)', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenAnswer(
        (_) async => respMap(200, path: '/templates/t1/variable-definitions'),
      );

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });

    test('body malformado → UnknownTemplatesFailure', () async {
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{'version': 1},
          path: '/templates/t1/variable-definitions',
        ),
      );

      await expectLater(
        ds.listVarDefs('t1'),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });

    test('tipo desconocido en el wire → ArgumentError (fail-loud)', () async {
      // Drift de contrato: el backend introdujo un tipo nuevo. El
      // cliente debe romper aquí en boot, no degradar.
      when(
        () =>
            dio.get<Map<String, dynamic>>('/templates/t1/variable-definitions'),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{
            'version': 1,
            'defs': <dynamic>[varDefJson(type: 'number')],
          },
          path: '/templates/t1/variable-definitions',
        ),
      );

      await expectLater(ds.listVarDefs('t1'), throwsArgumentError);
    });
  });

  group('DioTemplatesDatasource.byId', () {
    test('200 con templateResp → Template (con AIConfig completa)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1'),
      ).thenAnswer((_) async => respMap(200, body: tplJson()));

      final tpl = await ds.byId('t1');

      expect(tpl.id, 't1');
      expect(tpl.orgId, 'o1');
      expect(tpl.name, 'Soporte');
      expect(tpl.version, 1);
      expect(tpl.ai.provider, AIProvider.gemini);
      expect(tpl.ai.model, 'gemini-3.1-pro-preview');
      expect(tpl.ai.temperature, 0.7);
      expect(tpl.ai.thinkingLevel, ThinkingLevel.low);
      expect(tpl.ai.enabled, false);
      expect(tpl.ai.systemPrompt, '');
      expect(tpl.ai.contextMessages, 20);
      verify(() => dio.get<Map<String, dynamic>>('/templates/t1')).called(1);
    });

    test('404 → TemplatesNotFoundFailure', () async {
      // El backend devuelve 404 si el id no existe o no pertenece a la org;
      // el cliente no distingue (ambos son "no hay nada que mostrar").
      when(
        () => dio.get<Map<String, dynamic>>('/templates/desconocido'),
      ).thenThrow(badResponse(404, path: '/templates/desconocido'));

      await expectLater(
        ds.byId('desconocido'),
        throwsA(isA<TemplatesNotFoundFailure>()),
      );
    });

    test('403 → TemplatesForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1'),
      ).thenThrow(badResponse(403, path: '/templates/t1'));

      await expectLater(
        ds.byId('t1'),
        throwsA(isA<TemplatesForbiddenFailure>()),
      );
    });

    test('500 → TemplatesServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1'),
      ).thenThrow(badResponse(500, path: '/templates/t1'));

      await expectLater(ds.byId('t1'), throwsA(isA<TemplatesServerFailure>()));
    });

    test('timeout → TemplatesTimeoutFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/templates/t1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(ds.byId('t1'), throwsA(isA<TemplatesTimeoutFailure>()));
    });

    test('sin conexión → TemplatesNetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/templates/t1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(ds.byId('t1'), throwsA(isA<TemplatesNetworkFailure>()));
    });

    test('418 (no contemplado) → UnknownTemplatesFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1'),
      ).thenThrow(badResponse(418, path: '/templates/t1'));

      await expectLater(ds.byId('t1'), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test('body nulo → UnknownTemplatesFailure (contrato roto)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1'),
      ).thenAnswer((_) async => respMap(200));

      await expectLater(ds.byId('t1'), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test('body malformado → UnknownTemplatesFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/templates/t1')).thenAnswer(
        (_) async => respMap(200, body: <String, dynamic>{'id': 'x'}),
      );

      await expectLater(ds.byId('t1'), throwsA(isA<UnknownTemplatesFailure>()));
    });

    test(
      'proveedor desconocido en el wire → ArgumentError (fail-loud)',
      () async {
        when(() => dio.get<Map<String, dynamic>>('/templates/t1')).thenAnswer(
          (_) async => respMap(
            200,
            body: tplJson(ai: aiJson(provider: 'ANTHROPIC')),
          ),
        );

        await expectLater(ds.byId('t1'), throwsArgumentError);
      },
    );
  });

  group('DioTemplatesDatasource.update', () {
    const ai = AIConfig(
      enabled: false,
      provider: AIProvider.gemini,
      model: 'gemini-3.1-pro-preview',
      temperature: 0.7,
      thinkingLevel: ThinkingLevel.low,
      systemPrompt: 'Eres un asistente útil.',
      contextMessages: 20,
    );

    test(
      '200: serializa {name, version, ai} y devuelve la Template actualizada',
      () async {
        // Body capturado para validar la forma exacta del wire: el backend
        // espera snake_case en todos los campos del AIConfig anidado.
        final captured = <Map<String, dynamic>>[];
        when(
          () => dio.put<Map<String, dynamic>>(
            '/templates/t1',
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          captured.add(
            invocation.namedArguments[#data] as Map<String, dynamic>,
          );
          return respMap(200, body: tplJson(version: 2));
        });

        final got = await ds.update(
          id: 't1',
          name: 'Soporte v2',
          version: 1,
          ai: ai,
        );

        expect(got.id, 't1');
        expect(got.version, 2);
        expect(captured.single, <String, dynamic>{
          'name': 'Soporte v2',
          'version': 1,
          'ai': <String, dynamic>{
            'enabled': false,
            'provider': 'GEMINI',
            'model': 'gemini-3.1-pro-preview',
            'temperature': 0.7,
            'thinking_level': 'LOW',
            'system_prompt': 'Eres un asistente útil.',
            'context_messages': 20,
          },
        });
      },
    );

    test(
      'ai=null omite la clave `ai` del body (no toca config IA en backend)',
      () async {
        // Contrato del backend (putReq.AI con omitempty): clave ausente ⇒
        // config IA intacta. Distinto a enviar `ai: null` (que sería null
        // explícito y aún así el handler lo trata igual, pero el cliente
        // se mantiene fiel al patrón del wire).
        final captured = <Map<String, dynamic>>[];
        when(
          () => dio.put<Map<String, dynamic>>(
            '/templates/t1',
            data: any(named: 'data'),
          ),
        ).thenAnswer((invocation) async {
          captured.add(
            invocation.namedArguments[#data] as Map<String, dynamic>,
          );
          return respMap(200, body: tplJson(version: 2));
        });

        await ds.update(id: 't1', name: 'Otro', version: 1, ai: null);

        expect(captured.single.containsKey('ai'), isFalse);
        expect(captured.single, <String, dynamic>{
          'name': 'Otro',
          'version': 1,
        });
      },
    );

    test('409 → TemplatesConflictFailure (CAS — version stale)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(badResponse(409, path: '/templates/t1'));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesConflictFailure>()),
      );
    });

    test('422 → TemplatesInvalidUpdateFailure (no InvalidName)', () async {
      // PUT 422 puede ser ErrInvalidTemplate (name) o ErrInvalidAIConfig
      // (ai). El cubo InvalidUpdate los agrupa y NO se confunde con el
      // InvalidName de POST (operador del form de edit tiene varios
      // campos, no sabe a priori cuál disparó el 422).
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(badResponse(422, path: '/templates/t1'));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesInvalidUpdateFailure>()),
      );
    });

    test('404 → TemplatesNotFoundFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(badResponse(404, path: '/templates/t1'));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesNotFoundFailure>()),
      );
    });

    test('403 → TemplatesForbiddenFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(badResponse(403, path: '/templates/t1'));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesForbiddenFailure>()),
      );
    });

    test('500 → TemplatesServerFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(badResponse(500, path: '/templates/t1'));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesServerFailure>()),
      );
    });

    test('timeout → TemplatesTimeoutFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesTimeoutFailure>()),
      );
    });

    test('sin conexión → TemplatesNetworkFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<TemplatesNetworkFailure>()),
      );
    });

    test('body nulo → UnknownTemplatesFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => respMap(200, body: null));

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });

    test('body malformado → UnknownTemplatesFailure', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          '/templates/t1',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{'id': 't1'}, // faltan claves obligatorias
        ),
      );

      await expectLater(
        () => ds.update(id: 't1', name: 'x', version: 1, ai: ai),
        throwsA(isA<UnknownTemplatesFailure>()),
      );
    });
  });
}
