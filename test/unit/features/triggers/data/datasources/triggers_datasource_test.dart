import 'package:agentic/features/triggers/data/datasources/triggers_datasource.dart';
import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioTriggersDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioTriggersDatasource(dio);
  });

  Response<Map<String, dynamic>> respMap(
    int status, {
    Map<String, dynamic>? body,
    String path = '/templates/tpl1/triggers',
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status, {String path = '/templates/tpl1/triggers'}) =>
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );

  Map<String, dynamic> triggerJson({
    String id = 't1',
    String type = 'TEXT',
    String? matchType = 'CONTAINS',
    String keyword = 'hola',
    String labelId = '',
    String? labelAction,
    String scope = 'BOTH',
    bool isActive = true,
  }) => <String, dynamic>{
    'id': id,
    'templateId': 'tpl1',
    'flowId': 'f1',
    'type': type,
    if (matchType != null) 'matchType': matchType,
    if (keyword.isNotEmpty) 'keyword': keyword,
    if (labelId.isNotEmpty) 'labelId': labelId,
    if (labelAction != null) 'labelAction': labelAction,
    'scope': scope,
    'isActive': isActive,
    'createdAt': '2026-05-01T12:00:00Z',
    'updatedAt': '2026-05-01T12:00:00Z',
  };

  group('DioTriggersDatasource.listTriggers happy path', () {
    test('200 con items → List<Trigger> mapeada', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              triggerJson(),
              triggerJson(
                id: 't2',
                type: 'LABEL',
                matchType: null,
                keyword: '',
                labelId: 'vip',
                labelAction: 'ADD',
              ),
            ],
          },
        ),
      );

      final ts = await ds.listTriggers('tpl1');

      expect(ts, hasLength(2));
      expect(ts[0].triggerType, TriggerType.text);
      expect(ts[0].keyword, 'hola');
      expect(ts[1].triggerType, TriggerType.label);
      expect(ts[1].labelAction, LabelAction.add);

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/templates/tpl1/triggers');
    });

    test('200 con items vacío → lista vacía', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => respMap(200, body: <String, dynamic>{'items': <Map<String, dynamic>>[]}),
      );
      final ts = await ds.listTriggers('tpl1');
      expect(ts, isEmpty);
    });
  });

  group('DioTriggersDatasource.listTriggers failure mapping', () {
    test('403 → TriggersForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(403));
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<TriggersForbiddenFailure>()),
      );
    });

    test('404 → TriggersNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(404));
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<TriggersNotFoundFailure>()),
      );
    });

    test('500 → TriggersServerFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(503));
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<TriggersServerFailure>()),
      );
    });

    test('connectionError → TriggersNetworkFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/tpl1/triggers'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<TriggersNetworkFailure>()),
      );
    });

    test('connectionTimeout → TriggersTimeoutFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/templates/tpl1/triggers'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<TriggersTimeoutFailure>()),
      );
    });

    test('body null en 200 → UnknownTriggersFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => respMap(200));
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<UnknownTriggersFailure>()),
      );
    });

    test('body malformado (sin items) → UnknownTriggersFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => respMap(200, body: <String, dynamic>{'foo': 'bar'}),
      );
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<UnknownTriggersFailure>()),
      );
    });

    test('status no contemplado (418) → UnknownTriggersFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(418));
      await expectLater(
        () => ds.listTriggers('tpl1'),
        throwsA(isA<UnknownTriggersFailure>()),
      );
    });
  });
}
