import 'package:ataulfo/features/ai_log/data/ai_log_datasource.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:ataulfo/features/ai_log/domain/failures/ai_log_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioAiLogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioAiLogDatasource(dio);
  });

  Response<Map<String, dynamic>> ok(Map<String, dynamic> body) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: body,
      );

  test(
    '200 → página con entries tipadas (runId, reasoning, toolCalls)',
    () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => ok(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 42,
              'runId': 'run-7',
              'role': 'assistant',
              'content': 'Abrimos 9-18.',
              'reasoning': 'el doc dice 9-18',
              'toolCalls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'call_0',
                  'name': 'read_doc',
                  'arguments': <String, dynamic>{'name': 'horarios'},
                },
              ],
              'model': 'm1',
              'promptTokens': 10,
              'completionTokens': 5,
              'totalTokens': 15,
              'cachedTokens': 8,
              'costMicroUsd': 1234,
              'createdAt': '2026-06-12T12:00:00Z',
            },
          ],
          'nextBefore': 41,
        }),
      );

      final page = await ds.page(botId: 'b1', chatLid: 'chat@lid');

      expect(page.nextBefore, 41);
      expect(page.items, hasLength(1));
      final item = page.items.first;
      expect(item.id, 42);
      expect(item.runId, 'run-7');
      expect(item.role, AiLogRole.assistant);
      expect(item.reasoning, 'el doc dice 9-18');
      expect(item.toolCalls.single.name, 'read_doc');
      expect(item.toolCalls.single.argumentsJson, contains('horarios'));
      expect(item.model, 'm1');
      expect(item.promptTokens, 10);
      expect(item.completionTokens, 5);
      expect(item.totalTokens, 15);
      expect(item.cachedTokens, 8);
      expect(item.costMicroUsd, 1234);

      // El chatLid viaja ENCODEADO en el path y before/limit en el query.
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/sessions/b1/chat%40lid/ai-log');
    },
  );

  test('before viaja en el query cuando se pagina', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => ok(<String, dynamic>{'items': <dynamic>[]}));

    await ds.page(botId: 'b1', chatLid: 'c1', before: 41);

    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: captureAny(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], containsPair('before', 41));
  });

  test('corridas viejas sin cachedTokens/costMicroUsd ⇒ 0', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => ok(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'runId': 'run-old',
            'role': 'assistant',
            'promptTokens': 10,
            'completionTokens': 5,
            'totalTokens': 15,
            'createdAt': '2026-06-12T12:00:00Z',
          },
        ],
      }),
    );

    final page = await ds.page(botId: 'b1', chatLid: 'c1');
    final item = page.items.single;
    expect(item.cachedTokens, 0);
    expect(item.costMicroUsd, 0);
  });

  test('runForMessage 200 → runId; externalId viaja en el query', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => ok(<String, dynamic>{'runId': 'run-7'}));

    final runId = await ds.runForMessage(
      botId: 'b1',
      chatLid: 'chat@lid',
      externalId: 'WAM9',
    );

    expect(runId, 'run-7');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], '/sessions/b1/chat%40lid/ai-log/run-for-message');
    expect(captured[1], containsPair('externalId', 'WAM9'));
  });

  test('runForMessage 404 → null (el mensaje no lo generó la IA)', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final runId = await ds.runForMessage(
      botId: 'b1',
      chatLid: 'c1',
      externalId: 'WAM9',
    );
    expect(runId, isNull);
  });

  test('byRun → entries de la corrida; run viaja en el query', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => ok(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7,
            'runId': 'run-7',
            'role': 'assistant',
            'content': 'ya te confirmo',
            'createdAt': '2026-06-12T12:00:00Z',
          },
        ],
      }),
    );

    final entries = await ds.byRun(
      botId: 'b1',
      chatLid: 'chat@lid',
      runId: 'run-7',
    );

    expect(entries, hasLength(1));
    expect(entries.single.runId, 'run-7');
    final captured = verify(
      () => dio.get<Map<String, dynamic>>(
        captureAny(),
        queryParameters: captureAny(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).captured;
    expect(captured[0], '/sessions/b1/chat%40lid/ai-log');
    expect(captured[1], containsPair('run', 'run-7'));
  });

  test('403 → AiLogForbiddenFailure', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
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
      () => ds.page(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<AiLogForbiddenFailure>()),
    );
  });
}
