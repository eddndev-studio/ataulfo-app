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
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1'),
      ).thenAnswer((_) async => respMap(200, path: '/flows/f1', body: flowBody()));

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

      await expectLater(
        ds.flowById('f1'),
        throwsA(isA<FlowsServerFailure>()),
      );
    });

    test('body null → UnknownFlowsFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1'),
      ).thenAnswer((_) async => respMap(200, path: '/flows/f1'));

      await expectLater(
        ds.flowById('f1'),
        throwsA(isA<UnknownFlowsFailure>()),
      );
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
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1/steps'),
      ).thenAnswer(
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
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1/steps'),
      ).thenAnswer(
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
      when(
        () => dio.get<Map<String, dynamic>>('/flows/f1/steps'),
      ).thenThrow(
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
}
