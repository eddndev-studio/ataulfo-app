import 'package:ataulfo/features/labels/data/datasources/labels_datasource.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioLabelsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioLabelsDatasource(dio);
  });

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/labels'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/labels'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listLabels', () {
    test('GET /labels → List<Label>', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/labels'),
          statusCode: 200,
          data: <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'u1',
                'name': 'VIP',
                'color': '#34B7F1',
                'description': '',
              },
            ],
          },
        ),
      );
      final ls = await ds.listLabels();
      expect(ls.single.id, 'u1');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured.single, '/labels');
    });

    test('lista vacía es válida', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/labels'),
          statusCode: 200,
          data: <String, dynamic>{'items': <dynamic>[]},
        ),
      );
      expect(await ds.listLabels(), isEmpty);
    });

    test('403→Forbidden, 503→Server, body roto→Unknown', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenThrow(bad(403));
      await expectLater(
        () => ds.listLabels(),
        throwsA(isA<LabelsForbiddenFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenThrow(bad(503));
      await expectLater(
        () => ds.listLabels(),
        throwsA(isA<LabelsServerFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/labels'),
          statusCode: 200,
          data: <String, dynamic>{'foo': 'bar'},
        ),
      );
      await expectLater(
        () => ds.listLabels(),
        throwsA(isA<LabelsUnknownFailure>()),
      );
    });

    test('connectionError→Network, timeout→Timeout', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/labels'),
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        () => ds.listLabels(),
        throwsA(isA<LabelsNetworkFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/labels'),
          type: DioExceptionType.sendTimeout,
        ),
      );
      await expectLater(
        () => ds.listLabels(),
        throwsA(isA<LabelsTimeoutFailure>()),
      );
    });
  });
}
