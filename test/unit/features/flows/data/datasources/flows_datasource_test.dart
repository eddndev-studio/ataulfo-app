import 'package:agentic/features/flows/data/datasources/flows_datasource.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioFlowsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioFlowsDatasource(dio);
  });

  Response<Map<String, dynamic>> respMap(
    int status, {
    Map<String, dynamic>? body,
    String path = '/templates/t1/flows',
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {String path = '/templates/t1/flows'}) =>
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );

  Map<String, dynamic> flowJson({
    String id = 'f1',
    String name = 'Bienvenida',
    bool isActive = true,
    int version = 1,
  }) => <String, dynamic>{
    'id': id,
    'templateId': 't1',
    'name': name,
    'isActive': isActive,
    'cooldownMs': 0,
    'usageLimit': 0,
    'excludesFlows': <dynamic>[],
    'version': version,
    'createdAt': '2026-05-26T10:00:00Z',
    'updatedAt': '2026-05-26T10:00:00Z',
  };

  group('DioFlowsDatasource.listFlows', () {
    test('200 con {items:[...]} → List<Flow>', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{
            'items': <dynamic>[
              flowJson(),
              flowJson(
                id: 'f2',
                name: 'Despedida',
                isActive: false,
                version: 3,
              ),
            ],
          },
        ),
      );

      final flows = await ds.listFlows('t1');

      expect(flows, hasLength(2));
      expect(flows[0].id, 'f1');
      expect(flows[0].isActive, isTrue);
      expect(flows[1].id, 'f2');
      expect(flows[1].name, 'Despedida');
      expect(flows[1].isActive, isFalse);
      expect(flows[1].version, 3);
      verify(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).called(1);
    });

    test('200 con items vacío → List<Flow> vacía', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenAnswer(
        (_) async =>
            respMap(200, body: <String, dynamic>{'items': <dynamic>[]}),
      );

      expect(await ds.listFlows('t1'), isEmpty);
    });

    test('body null → UnknownFlowsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenAnswer((_) async => respMap(200));

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });

    test('timeout → FlowsTimeoutFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1/flows'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<FlowsTimeoutFailure>()),
      );
    });

    test('sin conexión → FlowsNetworkFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1/flows'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });

    test('403 → FlowsForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(badResponse(403));

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<FlowsForbiddenFailure>()),
      );
    });

    test('404 (template ajeno o inexistente) → FlowsNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(badResponse(404));

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });

    test('5xx → FlowsServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(badResponse(503));

      await expectLater(ds.listFlows('t1'), throwsA(isA<FlowsServerFailure>()));
    });

    test('status no contemplado → UnknownFlowsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenThrow(badResponse(418));

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });

    test('body malformado (items no es lista) → UnknownFlowsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/templates/t1/flows'),
      ).thenAnswer(
        (_) async => respMap(200, body: <String, dynamic>{'items': 'oops'}),
      );

      await expectLater(
        ds.listFlows('t1'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });
  });

  group('DioFlowsDatasource.flowById', () {
    Map<String, dynamic> flowBody({
      String id = 'f1',
      String name = 'Bienvenida',
      bool isActive = true,
      int version = 1,
    }) => <String, dynamic>{
      'id': id,
      'templateId': 't1',
      'name': name,
      'isActive': isActive,
      'cooldownMs': 0,
      'usageLimit': 0,
      'excludesFlows': <dynamic>[],
      'version': version,
      'createdAt': '2026-05-26T10:00:00Z',
      'updatedAt': '2026-05-26T10:00:00Z',
    };

    test('200 con flowResp → Flow', () async {
      when(() => dio.get<Map<String, dynamic>>('/flows/f1')).thenAnswer(
        (_) async => respMap(200, path: '/flows/f1', body: flowBody()),
      );

      final flow = await ds.flowById('f1');

      expect(flow.id, 'f1');
      expect(flow.name, 'Bienvenida');
      expect(flow.isActive, isTrue);
      verify(() => dio.get<Map<String, dynamic>>('/flows/f1')).called(1);
    });

    test('404 (flow ajeno o inexistente) → FlowsNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/flows/missing'),
      ).thenThrow(badResponse(404, path: '/flows/missing'));

      await expectLater(
        ds.flowById('missing'),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });

    test('5xx → FlowsServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1'),
      ).thenThrow(badResponse(500, path: '/flows/f1'));

      await expectLater(ds.flowById('f1'), throwsA(isA<FlowsServerFailure>()));
    });

    test('body null → UnknownFlowsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1'),
      ).thenAnswer((_) async => respMap(200, path: '/flows/f1'));

      await expectLater(ds.flowById('f1'), throwsA(isA<UnknownFlowsFailure>()));
    });
  });

  group('DioFlowsDatasource.listSteps', () {
    Map<String, dynamic> stepBody({
      String id = 's1',
      String type = 'TEXT',
      int order = 0,
    }) => <String, dynamic>{
      'id': id,
      'flowId': 'f1',
      'type': type,
      'order': order,
      'content': 'Hola',
      'mediaRef': '',
      'metadata': <String, dynamic>{},
      'delayMs': 0,
      'jitterPct': 0,
      'aiOnly': false,
      'createdAt': '2026-05-26T10:00:00Z',
      'updatedAt': '2026-05-26T10:00:00Z',
    };

    test('200 con {items:[...]} → List<Step>', () async {
      when(() => dio.get<Map<String, dynamic>>('/flows/f1/steps')).thenAnswer(
        (_) async => respMap(
          200,
          path: '/flows/f1/steps',
          body: <String, dynamic>{
            'items': <dynamic>[
              stepBody(),
              stepBody(id: 's2', type: 'IMAGE', order: 1),
            ],
          },
        ),
      );

      final steps = await ds.listSteps('f1');

      expect(steps, hasLength(2));
      expect(steps[0].id, 's1');
      expect(steps[0].type, fdom.StepType.text);
      expect(steps[1].type, fdom.StepType.image);
    });

    test('200 con items vacío → List<Step> vacía', () async {
      when(() => dio.get<Map<String, dynamic>>('/flows/f1/steps')).thenAnswer(
        (_) async => respMap(
          200,
          path: '/flows/f1/steps',
          body: <String, dynamic>{'items': <dynamic>[]},
        ),
      );

      expect(await ds.listSteps('f1'), isEmpty);
    });

    test('404 → FlowsNotFoundFailure (flow padre no existe)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/flows/missing/steps'),
      ).thenThrow(badResponse(404, path: '/flows/missing/steps'));

      await expectLater(
        ds.listSteps('missing'),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });

    test('timeout → FlowsTimeoutFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/flows/f1/steps')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/flows/f1/steps'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        ds.listSteps('f1'),
        throwsA(isA<FlowsTimeoutFailure>()),
      );
    });
  });

  group('DioFlowsDatasource.createFlow happy path', () {
    test(
      '201 con body devuelve Flow mapeado y POST al path correcto',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/templates/t1/flows'),
            statusCode: 201,
            data: flowJson(id: 'f-new', name: 'Bienvenida'),
          ),
        );

        final out = await ds.createFlow(templateId: 't1', name: 'Bienvenida');

        expect(out.id, 'f-new');
        expect(out.name, 'Bienvenida');
        expect(out.templateId, 't1');
        expect(out.version, 1);

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured[0], '/templates/t1/flows');
        expect(captured[1], <String, dynamic>{
          'name': 'Bienvenida',
          'cooldownMs': 0,
          'usageLimit': 0,
          'excludesFlows': <String>[],
        });
      },
    );
  });

  group('DioFlowsDatasource.createFlow failure mapping', () {
    test('422 → FlowsInvalidCreateFailure (nombre vacío, etc.)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(422));

      await expectLater(
        () => ds.createFlow(templateId: 't1', name: ''),
        throwsA(isA<FlowsInvalidCreateFailure>()),
      );
    });

    test('403 → FlowsForbiddenFailure (rol no alcanza)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(403));

      await expectLater(
        () => ds.createFlow(templateId: 't1', name: 'X'),
        throwsA(isA<FlowsForbiddenFailure>()),
      );
    });

    test('404 → FlowsNotFoundFailure (template padre no existe)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(404));

      await expectLater(
        () => ds.createFlow(templateId: 't1', name: 'X'),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });

    test('connectionError → FlowsNetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/t1/flows'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.createFlow(templateId: 't1', name: 'X'),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });

    test('body null en 201 → UnknownFlowsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/templates/t1/flows'),
          statusCode: 201,
          data: null,
        ),
      );

      await expectLater(
        () => ds.createFlow(templateId: 't1', name: 'X'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });
  });

  Map<String, dynamic> stepJson({
    String id = 's-new',
    String flowId = 'f1',
    String type = 'TEXT',
    int order = 0,
    String content = 'Hola',
    String mediaRef = '',
    int delayMs = 0,
    int jitterPct = 0,
    bool aiOnly = false,
  }) => <String, dynamic>{
    'id': id,
    'flowId': flowId,
    'type': type,
    'order': order,
    'content': content,
    'mediaRef': mediaRef,
    'metadata': <String, dynamic>{},
    'delayMs': delayMs,
    'jitterPct': jitterPct,
    'aiOnly': aiOnly,
    'createdAt': '2026-05-27T10:00:00Z',
    'updatedAt': '2026-05-27T10:00:00Z',
  };

  group('DioFlowsDatasource.createStep happy path', () {
    test('201 con body devuelve Step mapeado y POST al path correcto', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/flows/f1/steps'),
          statusCode: 201,
          data: stepJson(
            id: 's-new',
            order: 2,
            content: 'Bienvenido',
            delayMs: 1500,
            jitterPct: 10,
            aiOnly: true,
          ),
        ),
      );

      final out = await ds.createStep(
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 2,
        content: 'Bienvenido',
        mediaRef: '',
        delayMs: 1500,
        jitterPct: 10,
        aiOnly: true,
      );

      expect(out.id, 's-new');
      expect(out.flowId, 'f1');
      expect(out.type, fdom.StepType.text);
      expect(out.order, 2);
      expect(out.content, 'Bienvenido');
      expect(out.delayMs, 1500);
      expect(out.jitterPct, 10);
      expect(out.aiOnly, true);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/flows/f1/steps');
      expect(captured[1], <String, dynamic>{
        'type': 'TEXT',
        'order': 2,
        'content': 'Bienvenido',
        'mediaRef': '',
        'delayMs': 1500,
        'jitterPct': 10,
        'aiOnly': true,
      });
    });
  });

  group('DioFlowsDatasource.createStep failure mapping', () {
    test('422 → FlowsInvalidStepFailure (content vacío en TEXT, etc.)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(422, path: '/flows/f1/steps'));

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: '',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsInvalidStepFailure>()),
      );
    });

    test('404 → FlowsNotFoundFailure (flow padre no existe)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(404, path: '/flows/f1/steps'));

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'X',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });

    test('403 → FlowsForbiddenFailure (rol no alcanza)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(403, path: '/flows/f1/steps'));

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'X',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsForbiddenFailure>()),
      );
    });

    test('connectionError → FlowsNetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/flows/f1/steps'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'X',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });

    test('body null en 201 → UnknownFlowsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/flows/f1/steps'),
          statusCode: 201,
          data: null,
        ),
      );

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'X',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });

    test('timeout → FlowsTimeoutFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/flows/f1/steps'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: 'X',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsTimeoutFailure>()),
      );
    });
  });

  group('DioFlowsDatasource.patchStep happy path', () {
    test(
      '200 con body devuelve Step mapeado; body only-changed sin campos null',
      () async {
        when(
          () => dio.patch<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/steps/s1'),
            statusCode: 200,
            data: stepJson(id: 's1', content: 'Nuevo'),
          ),
        );

        final out = await ds.patchStep(stepId: 's1', content: 'Nuevo');

        expect(out.id, 's1');
        expect(out.content, 'Nuevo');

        final captured = verify(
          () => dio.patch<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured[0], '/steps/s1');
        // El body sólo trae los campos suministrados; el resto NO va con
        // valor null (omitir es preservar para el backend).
        expect(captured[1], <String, dynamic>{'content': 'Nuevo'});
      },
    );

    test('body con todos los campos opcionales viaja completo', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/steps/s1'),
          statusCode: 200,
          data: stepJson(id: 's1'),
        ),
      );

      await ds.patchStep(
        stepId: 's1',
        content: 'X',
        delayMs: 2000,
        jitterPct: 20,
        aiOnly: true,
      );

      final captured = verify(
        () => dio.patch<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[1], <String, dynamic>{
        'content': 'X',
        'delayMs': 2000,
        'jitterPct': 20,
        'aiOnly': true,
      });
    });
  });

  group('DioFlowsDatasource.patchStep failure mapping', () {
    DioException patchBadResponse(int status) => DioException(
      requestOptions: RequestOptions(path: '/steps/s1'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/steps/s1'),
        statusCode: status,
      ),
      type: DioExceptionType.badResponse,
    );

    test('422 → FlowsInvalidStepFailure', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(patchBadResponse(422));

      await expectLater(
        () => ds.patchStep(stepId: 's1', content: ''),
        throwsA(isA<FlowsInvalidStepFailure>()),
      );
    });

    test('404 → FlowsStepNotFoundFailure (step inexistente)', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(patchBadResponse(404));

      await expectLater(
        () => ds.patchStep(stepId: 's1', content: 'X'),
        throwsA(isA<FlowsStepNotFoundFailure>()),
      );
    });

    test('403 → FlowsForbiddenFailure', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(patchBadResponse(403));

      await expectLater(
        () => ds.patchStep(stepId: 's1', content: 'X'),
        throwsA(isA<FlowsForbiddenFailure>()),
      );
    });

    test('connectionError → FlowsNetworkFailure', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/steps/s1'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.patchStep(stepId: 's1', content: 'X'),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });

    test('body null en 200 → UnknownFlowsFailure', () async {
      when(
        () => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/steps/s1'),
          statusCode: 200,
          data: null,
        ),
      );

      await expectLater(
        () => ds.patchStep(stepId: 's1', content: 'X'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
    });
  });

  group('DioFlowsDatasource.deleteStep', () {
    test('204 OK — request path correcto', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/steps/s1'),
          statusCode: 204,
        ),
      );

      await ds.deleteStep('s1');

      final captured = verify(
        () => dio.delete<void>(captureAny(), options: any(named: 'options')),
      ).captured;
      expect(captured[0], '/steps/s1');
    });

    test('404 NO se mapea a failure — idempotente (servidor responde 204 igual)', () async {
      // El backend siempre devuelve 204 según handler — el 404 no llega.
      // Pero defensivamente: si llega 404, lo tratamos como éxido idempotente.
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/steps/s1'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/steps/s1'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      // No debe lanzar — el DELETE es idempotente HTTP.
      await ds.deleteStep('s1');
    });

    test('403 → FlowsForbiddenFailure', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/steps/s1'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/steps/s1'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        () => ds.deleteStep('s1'),
        throwsA(isA<FlowsForbiddenFailure>()),
      );
    });

    test('connectionError → FlowsNetworkFailure', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/steps/s1'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        () => ds.deleteStep('s1'),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });

    test('5xx → FlowsServerFailure', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/steps/s1'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/steps/s1'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        () => ds.deleteStep('s1'),
        throwsA(isA<FlowsServerFailure>()),
      );
    });
  });
}
