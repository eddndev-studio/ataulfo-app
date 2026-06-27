import 'package:ataulfo/features/monitor/data/datasources/monitor_catchup_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(Map<String, dynamic> body) => Response(
  requestOptions: RequestOptions(path: '/x'),
  statusCode: 200,
  data: body,
);

void main() {
  late _MockDio dio;
  late DioMonitorCatchupDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioMonitorCatchupDatasource(dio);
  });

  group('activeRun', () {
    test('devuelve runId+createdAt del item más reciente (?limit=1)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _resp(<String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'id': 9,
              'runId': 'R1',
              'role': 'assistant',
              'createdAt': '2026-06-12T10:00:00.000Z',
            },
          ],
        }),
      );
      final run = await ds.activeRun('b1', 'chat@s.lid');
      expect(run, isNotNull);
      expect(run!.runId, 'R1');
      expect(run.at, DateTime.utc(2026, 6, 12, 10));
      verify(
        () => dio.get<Map<String, dynamic>>(
          '/sessions/b1/${Uri.encodeComponent('chat@s.lid')}/ai-log',
          queryParameters: <String, dynamic>{'limit': 1},
        ),
      ).called(1);
    });

    test('items vacío ⇒ null', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _resp(<String, dynamic>{'items': <dynamic>[]}));
      expect(await ds.activeRun('b1', 'c1'), isNull);
    });

    test('runId vacío (histórico) ⇒ null', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _resp(<String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{'id': 1, 'runId': '', 'role': 'assistant'},
          ],
        }),
      );
      expect(await ds.activeRun('b1', 'c1'), isNull);
    });

    test('error HTTP ⇒ null (best-effort, no derriba el hilo)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(await ds.activeRun('b1', 'c1'), isNull);
    });
  });

  group('catchup', () {
    test('mapea assistant→aiTurn y tool→aiTool; user se omite', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _resp(<String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'runId': 'R1',
              'role': 'user',
              'content': 'hola',
              'createdAt': '2026-06-12T10:00:00.000Z',
            },
            <String, dynamic>{
              'id': 2,
              'runId': 'R1',
              'role': 'assistant',
              'model': 'gpt',
              'promptTokens': 10,
              'completionTokens': 5,
              'createdAt': '2026-06-12T10:00:01.000Z',
            },
            <String, dynamic>{
              'id': 3,
              'runId': 'R1',
              'role': 'tool',
              'toolName': 'send_message',
              'createdAt': '2026-06-12T10:00:02.000Z',
            },
          ],
        }),
      );
      final events = await ds.catchup('b1', 'c1', 'R1');
      expect(events, hasLength(2));
      expect(events[0].kind, MonitorEventKind.aiTurn);
      expect(events[0].model, 'gpt');
      expect(events[0].tokensIn, 10);
      expect(events[0].tokensOut, 5);
      expect(events[0].runId, 'R1');
      expect(events[1].kind, MonitorEventKind.aiTool);
      expect(events[1].toolName, 'send_message');
      verify(
        () => dio.get<Map<String, dynamic>>(
          '/sessions/b1/c1/ai-log',
          queryParameters: <String, dynamic>{'run': 'R1'},
        ),
      ).called(1);
    });
  });
}
