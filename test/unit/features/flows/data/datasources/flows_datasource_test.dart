import 'package:agentic/features/flows/data/datasources/flows_datasource.dart';
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
}
