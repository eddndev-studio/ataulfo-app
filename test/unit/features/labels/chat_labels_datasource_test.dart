import 'package:ataulfo/features/labels/data/datasources/chat_labels_datasource.dart';
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
  late DioChatLabelsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioChatLabelsDatasource(dio);
  });

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/x'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listForChat', () {
    test('GET /sessions/{botId}/{chatLid}/labels → List<Label>', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/x'),
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

      final ls = await ds.listForChat('b1', '5215512345678@s.whatsapp.net');
      expect(ls.single.id, 'u1');

      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: any(named: 'options'),
        ),
      ).captured;
      // El chatLid se percent-encodea en el path (los grupos llevan `@`).
      expect(
        captured.single,
        '/sessions/b1/${Uri.encodeComponent('5215512345678@s.whatsapp.net')}/labels',
      );
    });

    test('lista vacía es válida', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: <String, dynamic>{'items': <dynamic>[]},
        ),
      );
      expect(await ds.listForChat('b1', 'c1'), isEmpty);
    });

    test('403→Forbidden, 404→NotFound, body roto→Unknown', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(403));
      await expectLater(
        () => ds.listForChat('b1', 'c1'),
        throwsA(isA<LabelsForbiddenFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(404));
      await expectLater(
        () => ds.listForChat('b1', 'c1'),
        throwsA(isA<LabelsNotFoundFailure>()),
      );

      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
          data: <String, dynamic>{'foo': 'bar'},
        ),
      );
      await expectLater(
        () => ds.listForChat('b1', 'c1'),
        throwsA(isA<LabelsUnknownFailure>()),
      );
    });

    test('timeout → Timeout', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        () => ds.listForChat('b1', 'c1'),
        throwsA(isA<LabelsTimeoutFailure>()),
      );
    });
  });
}
