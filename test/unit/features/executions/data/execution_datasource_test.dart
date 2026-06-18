import 'package:ataulfo/features/executions/data/execution_datasource.dart';
import 'package:ataulfo/features/executions/domain/entities/execution.dart';
import 'package:ataulfo/features/executions/domain/failures/execution_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioExecutionsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioExecutionsDatasource(dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: body,
      );

  test('200 → ejecuciones tipadas desde el envelope {items}', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async => ok(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'exe-1',
            'botId': 'b1',
            'chatLid': 'chat@lid',
            'flowId': 'flw-1',
            'templateId': 'tpl-1',
            'status': 'FAILED',
            'currentStep': 2,
            'error': 'send_failed: upload failed with status code 400',
            'startedAt': '2026-06-14T09:00:00Z',
            'endedAt': '2026-06-14T09:00:05Z',
          },
          <String, dynamic>{
            'id': 'exe-2',
            'botId': 'b1',
            'chatLid': 'chat@lid',
            'flowId': 'flw-2',
            'templateId': 'tpl-1',
            'status': 'RUNNING',
            'currentStep': 0,
            'error': '',
            'startedAt': '2026-06-14T10:00:00Z',
            // endedAt ausente: una ejecución viva aún no terminó.
          },
        ],
      }),
    );

    final items = await ds.listBySession(botId: 'b1', chatLid: 'chat@lid');

    expect(items, hasLength(2));
    expect(items[0].id, 'exe-1');
    expect(items[0].status, ExecutionStatus.failed);
    expect(items[0].error, contains('status code 400'));
    expect(items[0].endedAt, isNotNull);
    expect(items[1].status, ExecutionStatus.running);
    expect(items[1].endedAt, isNull); // nullable cuando sigue corriendo

    // El chatLid viaja ENCODEADO en el path (los grupos llevan `@`).
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        captureAny(),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], '/sessions/b1/chat%40lid/executions');
  });

  test('lista vacía es válida', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => ok(<String, dynamic>{'items': <dynamic>[]}));

    final items = await ds.listBySession(botId: 'b1', chatLid: 'c1');

    expect(items, isEmpty);
  });

  test('403 → ExecutionForbiddenFailure (la vista es ADMIN+)', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 403,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      () => ds.listBySession(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<ExecutionForbiddenFailure>()),
    );
  });

  test('timeout → ExecutionNetworkFailure (reintentable)', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(
      () => ds.listBySession(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<ExecutionNetworkFailure>()),
    );
  });
}
