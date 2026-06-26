import 'package:ataulfo/features/ai_ledger/data/ai_ledger_datasource.dart';
import 'package:ataulfo/features/ai_ledger/domain/failures/ai_ledger_failure.dart';
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
  late DioAiLedgerDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioAiLedgerDatasource(dio);
  });

  test('page parsea items + nextBefore y encodea el chatLid', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => _resp(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 30,
            'runId': 'R1',
            'toolName': 'apply_label',
            'action': 'Aplicó una etiqueta',
            'detail': 'VIP',
            'createdAt': '2026-06-12T10:00:00.000Z',
          },
        ],
        'nextBefore': 20,
      }),
    );
    final page = await ds.page(botId: 'b1', chatLid: 'chat@s.lid');
    expect(page.items, hasLength(1));
    expect(page.items.first.toolName, 'apply_label');
    expect(page.items.first.action, 'Aplicó una etiqueta');
    expect(page.items.first.detail, 'VIP');
    expect(page.nextBefore, 20);
    verify(
      () => dio.get<Map<String, dynamic>>(
        '/sessions/b1/${Uri.encodeComponent('chat@s.lid')}/ai-ledger',
        queryParameters: <String, dynamic>{},
      ),
    ).called(1);
  });

  test('403 → AiLedgerForbiddenFailure', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 403,
        ),
      ),
    );
    await expectLater(
      () => ds.page(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<AiLedgerForbiddenFailure>()),
    );
  });

  test('timeout → AiLedgerNetworkFailure', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      () => ds.page(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<AiLedgerNetworkFailure>()),
    );
  });

  test('body nulo → AiLedgerUnknownFailure', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
      ),
    );
    await expectLater(
      () => ds.page(botId: 'b1', chatLid: 'c1'),
      throwsA(isA<AiLedgerUnknownFailure>()),
    );
  });
}
