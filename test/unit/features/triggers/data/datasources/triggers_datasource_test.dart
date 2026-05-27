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

  DioException badResponse(
    int status, {
    String path = '/templates/tpl1/triggers',
  }) => DioException(
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
    'matchType': ?matchType,
    if (keyword.isNotEmpty) 'keyword': keyword,
    if (labelId.isNotEmpty) 'labelId': labelId,
    'labelAction': ?labelAction,
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
        (_) async => respMap(
          200,
          body: <String, dynamic>{'items': <Map<String, dynamic>>[]},
        ),
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

  group('DioTriggersDatasource.createTrigger happy path', () {
    test('POST /templates/:templateId/triggers TEXT con body completo', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/templates/tpl1/triggers'),
          statusCode: 201,
          data: triggerJson(),
        ),
      );

      final t = await ds.createTrigger(
        templateId: 'tpl1',
        flowId: 'f1',
        triggerType: TriggerType.text,
        matchType: MatchType.contains,
        keyword: 'hola',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.both,
        isActive: true,
      );

      expect(t.id, 't1');
      expect(t.triggerType, TriggerType.text);
      expect(t.keyword, 'hola');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/templates/tpl1/triggers');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['flowId'], 'f1');
      expect(body['type'], 'TEXT');
      expect(body['matchType'], 'CONTAINS');
      expect(body['keyword'], 'hola');
      expect(body['scope'], 'BOTH');
      expect(body['isActive'], true);
      // El backend espeja TEXT triggers sin labelId/labelAction — el
      // cliente no manda esos campos en modo TEXT (omitempty del backend
      // los limpia de todos modos, pero ser explícito acota el contrato).
      expect(body.containsKey('labelId'), isFalse);
      expect(body.containsKey('labelAction'), isFalse);
    });

    test('POST LABEL no manda keyword/matchType', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/templates/tpl1/triggers'),
          statusCode: 201,
          data: triggerJson(
            id: 't2',
            type: 'LABEL',
            matchType: null,
            keyword: '',
            labelId: 'vip',
            labelAction: 'ADD',
          ),
        ),
      );

      final t = await ds.createTrigger(
        templateId: 'tpl1',
        flowId: 'f1',
        triggerType: TriggerType.label,
        matchType: null,
        keyword: '',
        labelId: 'vip',
        labelAction: LabelAction.add,
        scope: TriggerScope.both,
        isActive: true,
      );

      expect(t.triggerType, TriggerType.label);
      expect(t.labelAction, LabelAction.add);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      final body = captured[1] as Map<String, dynamic>;
      expect(body['type'], 'LABEL');
      expect(body['labelId'], 'vip');
      expect(body['labelAction'], 'ADD');
      expect(body.containsKey('keyword'), isFalse);
      expect(body.containsKey('matchType'), isFalse);
    });
  });

  group('DioTriggersDatasource.createTrigger failure mapping', () {
    Future<void> expectMappedTo<F>(int status) async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(status));
      await expectLater(
        () => ds.createTrigger(
          templateId: 'tpl1',
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.contains,
          keyword: 'hola',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
        throwsA(isA<F>()),
      );
    }

    test('422 → TriggersInvalidFailure', () => expectMappedTo<TriggersInvalidFailure>(422));
    test('403 → TriggersForbiddenFailure', () => expectMappedTo<TriggersForbiddenFailure>(403));
    test('404 → TriggersNotFoundFailure (template padre)', () => expectMappedTo<TriggersNotFoundFailure>(404));
    test('503 → TriggersServerFailure', () => expectMappedTo<TriggersServerFailure>(503));
  });

  group('DioTriggersDatasource.updateTrigger happy path', () {
    test('PUT /triggers/:id TEXT con documento completo (sin flowId)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/triggers/t1'),
          statusCode: 200,
          data: triggerJson(keyword: 'nueva'),
        ),
      );

      final t = await ds.updateTrigger(
        triggerId: 't1',
        triggerType: TriggerType.text,
        matchType: MatchType.contains,
        keyword: 'nueva',
        labelId: '',
        labelAction: null,
        scope: TriggerScope.incoming,
        isActive: false,
      );

      expect(t.id, 't1');
      expect(t.keyword, 'nueva');

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/triggers/t1');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['type'], 'TEXT');
      expect(body['matchType'], 'CONTAINS');
      expect(body['keyword'], 'nueva');
      expect(body['scope'], 'INCOMING');
      // PUT replace-completo: isActive viaja siempre, también cuando es
      // false — omitirlo reactivaría el trigger al default true.
      expect(body['isActive'], false);
      // flowId NO viaja en PUT: el backend lo preserva del existente
      // ignorando el del body. Mandar el del cliente sería ruido.
      expect(body.containsKey('flowId'), isFalse);
    });

    test('PUT LABEL preserva campos del modo (sin keyword/matchType)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/triggers/t2'),
          statusCode: 200,
          data: triggerJson(
            id: 't2',
            type: 'LABEL',
            matchType: null,
            keyword: '',
            labelId: 'vip',
            labelAction: 'REMOVE',
          ),
        ),
      );

      final t = await ds.updateTrigger(
        triggerId: 't2',
        triggerType: TriggerType.label,
        matchType: null,
        keyword: '',
        labelId: 'vip',
        labelAction: LabelAction.remove,
        scope: TriggerScope.both,
        isActive: true,
      );

      expect(t.labelAction, LabelAction.remove);

      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      final body = captured[1] as Map<String, dynamic>;
      expect(body['labelId'], 'vip');
      expect(body['labelAction'], 'REMOVE');
      expect(body.containsKey('keyword'), isFalse);
      expect(body.containsKey('matchType'), isFalse);
    });
  });

  group('DioTriggersDatasource.updateTrigger failure mapping', () {
    Future<void> expectMappedTo<F>(int status) async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(badResponse(status, path: '/triggers/t1'));
      await expectLater(
        () => ds.updateTrigger(
          triggerId: 't1',
          triggerType: TriggerType.text,
          matchType: MatchType.contains,
          keyword: 'x',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
        throwsA(isA<F>()),
      );
    }

    test('422 → TriggersInvalidFailure', () => expectMappedTo<TriggersInvalidFailure>(422));
    test('404 → TriggersNotFoundFailure (trigger gone)', () => expectMappedTo<TriggersNotFoundFailure>(404));
    test('403 → TriggersForbiddenFailure', () => expectMappedTo<TriggersForbiddenFailure>(403));
  });
}
