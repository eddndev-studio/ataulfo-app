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

  Response<T> resp<T>(int status, String path, {T? data}) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: data,
  );

  DioException badResponse(int status, String path) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('startSession', () {
    test('202 → completa sin error', () async {
      when(
        () => dio.post<void>('/bots/b1/session'),
      ).thenAnswer((_) async => resp<void>(202, '/bots/b1/session'));

      await ds.startSession('b1');

      verify(() => dio.post<void>('/bots/b1/session')).called(1);
    });

    test('403 → BotsForbiddenFailure', () async {
      when(
        () => dio.post<void>('/bots/b1/session'),
      ).thenThrow(badResponse(403, '/bots/b1/session'));

      expect(() => ds.startSession('b1'), throwsA(isA<BotsForbiddenFailure>()));
    });

    test('500 → BotsServerFailure', () async {
      when(
        () => dio.post<void>('/bots/b1/session'),
      ).thenThrow(badResponse(500, '/bots/b1/session'));

      expect(() => ds.startSession('b1'), throwsA(isA<BotsServerFailure>()));
    });

    test('receiveTimeout → BotsTimeoutFailure', () async {
      when(() => dio.post<void>('/bots/b1/session')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bots/b1/session'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(() => ds.startSession('b1'), throwsA(isA<BotsTimeoutFailure>()));
    });
  });

  group('stopSession', () {
    test('204 → completa (idempotente)', () async {
      when(
        () => dio.delete<void>('/bots/b1/session'),
      ).thenAnswer((_) async => resp<void>(204, '/bots/b1/session'));

      await ds.stopSession('b1');

      verify(() => dio.delete<void>('/bots/b1/session')).called(1);
    });
  });

  group('issueConnectLink', () {
    test('201 {token,expiresAt} → ConnectLink con url desde baseUrl', () async {
      when(
        () => dio.post<Map<String, dynamic>>('/bots/b1/connect-token'),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>(
          201,
          '/bots/b1/connect-token',
          data: <String, dynamic>{
            'token': 'abcDEF123-_xyz',
            'expiresAt': '2026-05-29T12:30:00Z',
          },
        ),
      );

      final link = await ds.issueConnectLink('b1');

      expect(link.url, 'http://10.0.2.2:8080/connect?token=abcDEF123-_xyz');
      expect(link.expiresAt, DateTime.utc(2026, 5, 29, 12, 30, 0));
    });

    test('baseUrl con barra final no duplica la barra', () async {
      when(
        () => dio.options,
      ).thenReturn(BaseOptions(baseUrl: 'https://api.ataulfo.app/'));
      when(
        () => dio.post<Map<String, dynamic>>('/bots/b1/connect-token'),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>(
          201,
          '/bots/b1/connect-token',
          data: <String, dynamic>{
            'token': 'tok',
            'expiresAt': '2026-05-29T12:30:00Z',
          },
        ),
      );

      final link = await ds.issueConnectLink('b1');

      expect(link.url, 'https://api.ataulfo.app/connect?token=tok');
    });

    test('body null → UnknownBotsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>('/bots/b1/connect-token'),
      ).thenAnswer(
        (_) async => resp<Map<String, dynamic>>(201, '/bots/b1/connect-token'),
      );

      expect(
        () => ds.issueConnectLink('b1'),
        throwsA(isA<UnknownBotsFailure>()),
      );
    });

    test('404 → BotsNotFoundFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>('/bots/b1/connect-token'),
      ).thenThrow(badResponse(404, '/bots/b1/connect-token'));

      expect(
        () => ds.issueConnectLink('b1'),
        throwsA(isA<BotsNotFoundFailure>()),
      );
    });
  });
}
