import 'package:ataulfo/features/flow_run/data/datasources/flow_run_datasource.dart';
import 'package:ataulfo/features/flow_run/domain/failures/flow_run_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioFlowRunDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioFlowRunDatasource(dio);
  });

  DioException badResponse(int status, {dynamic body}) => DioException(
    requestOptions: RequestOptions(path: '/p'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/p'),
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listRunnable', () {
    void stubGet(Response<List<dynamic>> r) {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer((_) async => r);
    }

    test('200 [{id,name}] → RunnableFlow list + path', () async {
      stubGet(
        Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: <dynamic>[
            <String, dynamic>{'id': 'f1', 'name': 'Bienvenida'},
            <String, dynamic>{'id': 'f2', 'name': 'Precios'},
          ],
        ),
      );
      final flows = await ds.listRunnable('b1');
      expect(flows, hasLength(2));
      expect(flows[0].id, 'f1');
      expect(flows[1].name, 'Precios');
      final path = verify(
        () => dio.get<List<dynamic>>(captureAny()),
      ).captured.single;
      expect(path, '/sessions/b1/flows');
    });

    test('403 → FlowRunForbiddenFailure', () async {
      when(() => dio.get<List<dynamic>>(any())).thenThrow(badResponse(403));
      await expectLater(
        ds.listRunnable('b1'),
        throwsA(isA<FlowRunForbiddenFailure>()),
      );
    });

    test('500 → FlowRunServerFailure', () async {
      when(() => dio.get<List<dynamic>>(any())).thenThrow(badResponse(500));
      await expectLater(
        ds.listRunnable('b1'),
        throwsA(isA<FlowRunServerFailure>()),
      );
    });
  });

  group('run', () {
    void stubPost(Response<Map<String, dynamic>> r) {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => r);
    }

    test('202 {executionId} → id + path percent-encodeado', () async {
      stubPost(
        Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 202,
          data: <String, dynamic>{'executionId': 'exe-9'},
        ),
      );
      final id = await ds.run(botId: 'b1', chatLid: '12036@g.us', flowId: 'f1');
      expect(id, 'exe-9');
      final path = verify(
        () => dio.post<Map<String, dynamic>>(captureAny()),
      ).captured.single;
      expect(path, '/sessions/b1/12036%40g.us/flows/f1/run');
    });

    test('409 con reason → FlowRunBlockedFailure(reason)', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        badResponse(409, body: <String, dynamic>{'reason': 'COOLDOWN'}),
      );
      await expectLater(
        ds.run(botId: 'b1', chatLid: 'c1', flowId: 'f1'),
        throwsA(
          isA<FlowRunBlockedFailure>().having(
            (f) => f.reason,
            'reason',
            'COOLDOWN',
          ),
        ),
      );
    });

    test('409 sin reason → FlowRunConflictFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(409));
      await expectLater(
        ds.run(botId: 'b1', chatLid: 'c1', flowId: 'f1'),
        throwsA(isA<FlowRunConflictFailure>()),
      );
    });

    test('423 → FlowRunPausedFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(423));
      await expectLater(
        ds.run(botId: 'b1', chatLid: 'c1', flowId: 'f1'),
        throwsA(isA<FlowRunPausedFailure>()),
      );
    });

    test('404 → FlowRunNotFoundFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any()),
      ).thenThrow(badResponse(404));
      await expectLater(
        ds.run(botId: 'b1', chatLid: 'c1', flowId: 'f1'),
        throwsA(isA<FlowRunNotFoundFailure>()),
      );
    });

    test('timeout → FlowRunTimeoutFailure', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        ds.run(botId: 'b1', chatLid: 'c1', flowId: 'f1'),
        throwsA(isA<FlowRunTimeoutFailure>()),
      );
    });
  });
}
