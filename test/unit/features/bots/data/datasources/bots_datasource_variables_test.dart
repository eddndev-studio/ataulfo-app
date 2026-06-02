import 'package:ataulfo/features/bots/data/datasources/bots_datasource.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioBotsDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioBotsDatasource(dio);
  });

  Response<Map<String, dynamic>> respMap(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/bots/b1/variables'),
    statusCode: status,
    data: body,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: '/bots/b1/variables'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/bots/b1/variables'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('DioBotsDatasource.getVariables', () {
    test(
      '200 con {version, template_id, variable_values} → snapshot precargable',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
        ).thenAnswer(
          (_) async => respMap(
            200,
            body: <String, dynamic>{
              'version': 7,
              'template_id': 't1',
              'variable_values': <String, dynamic>{
                'tono': 'formal',
                'firma': 'Soporte Ataulfo',
              },
            },
          ),
        );

        final snap = await ds.getVariables('b1');

        expect(snap.version, 7);
        expect(snap.templateId, 't1');
        expect(snap.values, <String, String>{
          'tono': 'formal',
          'firma': 'Soporte Ataulfo',
        });
        verify(
          () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
        ).called(1);
      },
    );

    test('200 con variable_values:{} → values vacío (sin overrides)', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
      ).thenAnswer(
        (_) async => respMap(
          200,
          body: <String, dynamic>{
            'version': 1,
            'template_id': 't1',
            'variable_values': <String, dynamic>{},
          },
        ),
      );

      final snap = await ds.getVariables('b1');

      expect(snap.values, isEmpty);
      expect(snap.version, 1);
    });

    test('404 → BotsNotFoundFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
      ).thenThrow(badResponse(404));
      expect(() => ds.getVariables('b1'), throwsA(isA<BotsNotFoundFailure>()));
    });

    test('403 (rol no admin) → BotsForbiddenFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
      ).thenThrow(badResponse(403));
      expect(() => ds.getVariables('b1'), throwsA(isA<BotsForbiddenFailure>()));
    });

    test('connectionError → BotsNetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/bots/b1/variables')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1/variables'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(() => ds.getVariables('b1'), throwsA(isA<BotsNetworkFailure>()));
    });

    test(
      'variable_values:null (drift) → UnknownBotsFailure (fail-loud)',
      () async {
        when(
          () => dio.get<Map<String, dynamic>>('/bots/b1/variables'),
        ).thenAnswer(
          (_) async => respMap(
            200,
            body: <String, dynamic>{
              'version': 1,
              'template_id': 't1',
              'variable_values': null,
            },
          ),
        );
        expect(() => ds.getVariables('b1'), throwsA(isA<UnknownBotsFailure>()));
      },
    );
  });
}
