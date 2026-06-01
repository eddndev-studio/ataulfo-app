import 'package:ataulfo/features/wa_labels/data/datasources/wa_catalog_datasource.dart';
import 'package:ataulfo/features/wa_labels/domain/failures/wa_labels_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioWaCatalogDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioWaCatalogDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
    String path = '/bots/b1/wa-labels',
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException bad(int status, {String path = '/bots/b1/wa-labels'}) =>
      DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );

  Map<String, dynamic> labelJson({
    String waLabelId = '1000',
    String name = 'VIP',
    int color = 3,
    bool deleted = false,
  }) => <String, dynamic>{
    'waLabelId': waLabelId,
    'name': name,
    'color': color,
    'deleted': deleted,
  };

  group('listCatalog', () {
    test('200 con items → List<WaLabel> con orden y tombstones', () async {
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
              labelJson(),
              labelJson(waLabelId: '1001', name: '', color: 0, deleted: true),
            ],
          },
        ),
      );

      final ls = await ds.listCatalog('b1');
      expect(ls, hasLength(2));
      expect(ls[0].waLabelId, '1000');
      expect(ls[0].color, 3);
      expect(ls[1].deleted, isTrue);

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/bots/b1/wa-labels');
    });

    test('200 items vacío → lista vacía', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => resp(200, body: <String, dynamic>{'items': <dynamic>[]}),
      );
      expect(await ds.listCatalog('b1'), isEmpty);
    });

    test('403→Forbidden, 404→NotFound, 503→Server', () async {
      for (final pair in <List<Object>>[
        <Object>[403, WaLabelsForbiddenFailure],
        <Object>[404, WaLabelsNotFoundFailure],
        <Object>[503, WaLabelsServerFailure],
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
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        () => ds.listCatalog('b1'),
        throwsA(isA<WaLabelsNetworkFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        () => ds.listCatalog('b1'),
        throwsA(isA<WaLabelsTimeoutFailure>()),
      );
    });

    test('body null → Unknown; body malformado → Unknown', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => resp(200));
      await expectLater(
        () => ds.listCatalog('b1'),
        throwsA(isA<WaLabelsUnknownFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => resp(200, body: <String, dynamic>{'foo': 'bar'}),
      );
      await expectLater(
        () => ds.listCatalog('b1'),
        throwsA(isA<WaLabelsUnknownFailure>()),
      );
    });
  });

  group('createLabel', () {
    test('POST con body {name,color} → 201 WaLabel', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels'),
          statusCode: 201,
          data: labelJson(waLabelId: '1000', name: 'VIP', color: 3),
        ),
      );

      final l = await ds.createLabel(botId: 'b1', name: 'VIP', color: 3);
      expect(l.waLabelId, '1000');
      expect(l.color, 3);

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/bots/b1/wa-labels');
      final body = captured[1] as Map<String, dynamic>;
      expect(body['name'], 'VIP');
      expect(body['color'], 3);
    });

    test('color 0 viaja en el body (no se omite)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels'),
          statusCode: 201,
          data: labelJson(color: 0),
        ),
      );
      await ds.createLabel(botId: 'b1', name: 'Cero', color: 0);
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect((captured.single as Map<String, dynamic>)['color'], 0);
    });

    test('422→Invalid, 409→NotConnected, 502→Upstream', () async {
      for (final pair in <List<Object>>[
        <Object>[422, WaLabelsInvalidFailure],
        <Object>[409, WaLabelsNotConnectedFailure],
        <Object>[502, WaLabelsUpstreamFailure],
      ]) {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(bad(pair[0] as int));
        await expectLater(
          () => ds.createLabel(botId: 'b1', name: 'x', color: 1),
          throwsA(predicate((e) => e.runtimeType == pair[1])),
        );
      }
    });

    test('404→NotFound (bot ajeno), 503→Server', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(404));
      await expectLater(
        () => ds.createLabel(botId: 'b1', name: 'x', color: 1),
        throwsA(isA<WaLabelsNotFoundFailure>()),
      );
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(503));
      await expectLater(
        () => ds.createLabel(botId: 'b1', name: 'x', color: 1),
        throwsA(isA<WaLabelsServerFailure>()),
      );
    });
  });

  group('updateLabel', () {
    test(
      'PUT /bots/b1/wa-labels/1000 con body completo → 200 WaLabel',
      () async {
        when(
          () => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/bots/b1/wa-labels/1000'),
            statusCode: 200,
            data: labelJson(name: 'Oro', color: 5),
          ),
        );

        final l = await ds.updateLabel(
          botId: 'b1',
          waLabelId: '1000',
          name: 'Oro',
          color: 5,
        );
        expect(l.name, 'Oro');

        final captured = verify(
          () => dio.put<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured[0], '/bots/b1/wa-labels/1000');
        final body = captured[1] as Map<String, dynamic>;
        expect(body['name'], 'Oro');
        expect(body['color'], 5);
      },
    );

    test('409→NotConnected', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(409, path: '/bots/b1/wa-labels/1000'));
      await expectLater(
        () =>
            ds.updateLabel(botId: 'b1', waLabelId: '1000', name: 'x', color: 1),
        throwsA(isA<WaLabelsNotConnectedFailure>()),
      );
    });
  });

  group('deleteLabel', () {
    test('DELETE /bots/b1/wa-labels/1000 200 sin body → completa', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/bots/b1/wa-labels/1000'),
          statusCode: 200,
        ),
      );

      await ds.deleteLabel(botId: 'b1', waLabelId: '1000');

      final captured = verify(
        () => dio.delete<void>(captureAny(), options: any(named: 'options')),
      ).captured;
      expect(captured.single, '/bots/b1/wa-labels/1000');
    });

    test('404→NotFound (NO idempotente: 404 = bot ajeno)', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(bad(404, path: '/bots/b1/wa-labels/1000'));
      await expectLater(
        () => ds.deleteLabel(botId: 'b1', waLabelId: '1000'),
        throwsA(isA<WaLabelsNotFoundFailure>()),
      );
    });

    test('502→Upstream', () async {
      when(
        () => dio.delete<void>(any(), options: any(named: 'options')),
      ).thenThrow(bad(502, path: '/bots/b1/wa-labels/1000'));
      await expectLater(
        () => ds.deleteLabel(botId: 'b1', waLabelId: '1000'),
        throwsA(isA<WaLabelsUpstreamFailure>()),
      );
    });
  });
}
