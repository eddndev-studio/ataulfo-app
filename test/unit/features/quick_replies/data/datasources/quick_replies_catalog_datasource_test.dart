import 'package:ataulfo/features/quick_replies/data/datasources/quick_replies_catalog_datasource.dart';
import 'package:ataulfo/features/quick_replies/domain/failures/quick_replies_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioQuickRepliesCatalogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioQuickRepliesCatalogDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/bots/b1/quick-replies'),
    statusCode: status,
    data: body,
  );

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/bots/b1/quick-replies'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/bots/b1/quick-replies'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> qrJson({
    String id = '61',
    String shortcut = 'saludo',
    String message = 'Hola',
    bool deleted = false,
  }) => <String, dynamic>{
    'waQuickReplyId': id,
    'shortcut': shortcut,
    'message': message,
    'keywords': <String>[],
    'count': 0,
    'deleted': deleted,
    'associatedLabelIds': <String>[],
  };

  test(
    'GET /bots/{botId}/quick-replies → List<QuickReply> con tombstones',
    () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => resp(
          200,
          body: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              qrJson(),
              qrJson(id: '62', shortcut: '', message: '', deleted: true),
            ],
          },
        ),
      );

      final qs = await ds.listCatalog('b1');
      expect(qs, hasLength(2));
      expect(qs[0].waQuickReplyId, '61');
      expect(qs[0].message, 'Hola');
      expect(qs[1].deleted, isTrue);

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/bots/b1/quick-replies');
    },
  );

  test('items vacío → lista vacía', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async => resp(200, body: <String, dynamic>{'items': <dynamic>[]}),
    );
    expect(await ds.listCatalog('b1'), isEmpty);
  });

  test('403→Forbidden, 404→NotFound, 503→Server', () async {
    for (final pair in <List<Object>>[
      <Object>[403, QuickRepliesForbiddenFailure],
      <Object>[404, QuickRepliesNotFoundFailure],
      <Object>[503, QuickRepliesServerFailure],
    ]) {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(pair[0] as int));
      await expectLater(
        () => ds.listCatalog('b1'),
        throwsA(predicate((e) => e.runtimeType == pair[1])),
      );
    }
  });

  test('connectionError→Network, timeout→Timeout', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/bots/b1/quick-replies'),
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      () => ds.listCatalog('b1'),
      throwsA(isA<QuickRepliesNetworkFailure>()),
    );

    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/bots/b1/quick-replies'),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(
      () => ds.listCatalog('b1'),
      throwsA(isA<QuickRepliesTimeoutFailure>()),
    );
  });

  test('body null → Unknown; body malformado → Unknown', () async {
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => resp(200));
    await expectLater(
      () => ds.listCatalog('b1'),
      throwsA(isA<QuickRepliesUnknownFailure>()),
    );

    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => resp(200, body: <String, dynamic>{'foo': 'bar'}));
    await expectLater(
      () => ds.listCatalog('b1'),
      throwsA(isA<QuickRepliesUnknownFailure>()),
    );
  });
}
