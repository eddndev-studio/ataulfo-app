import 'package:ataulfo/features/bots/data/datasources/bot_session_datasource.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioBotSessionDatasource ds;

  setUp(() {
    dio = _MockDio();
    when(
      () => dio.options,
    ).thenReturn(BaseOptions(baseUrl: 'http://10.0.2.2:8080'));
    ds = DioBotSessionDatasource(dio);
  });

  const path = '/bots/b1/session/pair-phone';

  Response<T> resp<T>(int status, {T? data}) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: data,
  );

  DioException badResponse(int status) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  When<Future<Response<Map<String, dynamic>>>> stubPost() => when(
    () =>
        dio.post<Map<String, dynamic>>(path, data: any<Object?>(named: 'data')),
  );

  group('pairPhone', () {
    test(
      '200 {code} → devuelve el código tal cual; path y body exactos',
      () async {
        stubPost().thenAnswer(
          (_) async => resp<Map<String, dynamic>>(
            200,
            data: <String, dynamic>{'code': 'WZYX-K9PT'},
          ),
        );

        final code = await ds.pairPhone('b1', '5215512345678');

        expect(code, 'WZYX-K9PT');
        verify(
          () => dio.post<Map<String, dynamic>>(
            path,
            data: <String, dynamic>{'phone': '5215512345678'},
          ),
        ).called(1);
      },
    );

    test('400 → BotsPhoneRejectedFailure (phone vacío)', () async {
      stubPost().thenThrow(badResponse(400));

      expect(
        () => ds.pairPhone('b1', ''),
        throwsA(isA<BotsPhoneRejectedFailure>()),
      );
    });

    test('409 → BotsPairingNotStartedFailure', () async {
      stubPost().thenThrow(badResponse(409));

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<BotsPairingNotStartedFailure>()),
      );
    });

    test('422 → BotsPhoneRejectedFailure (cajón del wire)', () async {
      stubPost().thenThrow(badResponse(422));

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<BotsPhoneRejectedFailure>()),
      );
    });

    test('403 → BotsForbiddenFailure', () async {
      stubPost().thenThrow(badResponse(403));

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<BotsForbiddenFailure>()),
      );
    });

    test('404 → BotsNotFoundFailure', () async {
      stubPost().thenThrow(badResponse(404));

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });

    test('body null → UnknownBotsFailure', () async {
      stubPost().thenAnswer((_) async => resp<Map<String, dynamic>>(200));

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('code no-String → UnknownBotsFailure (parseo defensivo)', () async {
      stubPost().thenAnswer(
        (_) async => resp<Map<String, dynamic>>(
          200,
          data: <String, dynamic>{'code': 1234},
        ),
      );

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('connectionError → BotsNetworkFailure', () async {
      stubPost().thenThrow(
        DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => ds.pairPhone('b1', '5215512345678'),
        throwsA(isA<BotsNetworkFailure>()),
      );
    });
  });

  group('aislamiento por-endpoint del mapeo nuevo', () {
    test('409 de startSession sigue colapsando a UnknownBotsFailure', () async {
      when(() => dio.post<void>('/bots/b1/session')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1/session'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/bots/b1/session'),
            statusCode: 409,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(() => ds.startSession('b1'), throwsA(isA<UnknownBotsFailure>()));
    });
  });
}
