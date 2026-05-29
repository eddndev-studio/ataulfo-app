import 'package:ataulfo/features/auth/data/datasources/auth_datasource.dart';
import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioAuthDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioAuthDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/auth/login'),
    statusCode: status,
    data: body,
  );

  group('DioAuthDatasource.login', () {
    test('200 con par de tokens → AuthTokens', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => resp(
          200,
          body: <String, dynamic>{
            'access_token': 'a.b.c',
            'refresh_token': 'r-32',
            'token_type': 'Bearer',
            'expires_in': 900,
          },
        ),
      );

      final tokens = await ds.login(
        email: 'op@example.com',
        password: 'hunter2-secret',
      );

      expect(
        tokens,
        const AuthTokens(
          accessToken: 'a.b.c',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: <String, dynamic>{
            'email': 'op@example.com',
            'password': 'hunter2-secret',
          },
        ),
      ).called(1);
    });

    test('401 → InvalidCredentialsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(401),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'bad'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('429 → RateLimitedFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(429),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<RateLimitedFailure>()),
      );
    });

    test('timeout de red → NetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('500 → UnknownAuthFailure (no se filtra el status crudo)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(500),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });
  });

  Response<Map<String, dynamic>> refreshResp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/auth/refresh'),
    statusCode: status,
    data: body,
  );

  group('DioAuthDatasource.refresh', () {
    test('200 con par rotado → AuthTokens nuevo', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => refreshResp(
          200,
          body: <String, dynamic>{
            'access_token': 'a2.b2.c2',
            'refresh_token': 'r-33-rotated',
            'token_type': 'Bearer',
            'expires_in': 900,
          },
        ),
      );

      final tokens = await ds.refresh('r-32-original');

      expect(
        tokens,
        const AuthTokens(
          accessToken: 'a2.b2.c2',
          refreshToken: 'r-33-rotated',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: <String, dynamic>{'refresh_token': 'r-32-original'},
        ),
      ).called(1);
    });

    test(
      '401 → InvalidCredentialsFailure (refresh inválido/revocado)',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            response: refreshResp(401),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          ds.refresh('r-revoked'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
      },
    );

    test('timeout → NetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(ds.refresh('r-32'), throwsA(isA<NetworkFailure>()));
    });

    test('500 → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          response: refreshResp(500),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(ds.refresh('r-32'), throwsA(isA<UnknownAuthFailure>()));
    });

    test('body nulo/malformado → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => refreshResp(200));

      await expectLater(ds.refresh('r-32'), throwsA(isA<UnknownAuthFailure>()));
    });
  });

  Response<Map<String, dynamic>> meHttpResp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/auth/me'),
    statusCode: status,
    data: body,
  );

  group('DioAuthDatasource.me', () {
    test('200 con {user_id, org_id, role} → Identity', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenAnswer(
        (_) async => meHttpResp(
          200,
          body: <String, dynamic>{
            'user_id': 'u-123',
            'org_id': 'o-456',
            'role': 'OWNER',
            'email': 'op@example.com',
          },
        ),
      );

      final identity = await ds.me();

      expect(
        identity,
        const Identity(
          userId: 'u-123',
          orgId: 'o-456',
          role: 'OWNER',
          email: 'op@example.com',
        ),
      );
      verify(() => dio.get<Map<String, dynamic>>('/auth/me')).called(1);
    });

    test(
      '401 → InvalidCredentialsFailure (token inválido tras refresh)',
      () async {
        when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/me'),
            response: meHttpResp(401),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(ds.me(), throwsA(isA<InvalidCredentialsFailure>()));
      },
    );

    test('timeout → NetworkFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(ds.me(), throwsA(isA<NetworkFailure>()));
    });

    test('500 → UnknownAuthFailure', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          response: meHttpResp(500),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(ds.me(), throwsA(isA<UnknownAuthFailure>()));
    });

    test('body nulo → UnknownAuthFailure', () async {
      when(
        () => dio.get<Map<String, dynamic>>('/auth/me'),
      ).thenAnswer((_) async => meHttpResp(200));

      await expectLater(ds.me(), throwsA(isA<UnknownAuthFailure>()));
    });
  });

  Response<void> logoutResp(int status) => Response<void>(
    requestOptions: RequestOptions(path: '/auth/logout'),
    statusCode: status,
  );

  group('DioAuthDatasource.logout', () {
    test('204 → completa sin excepción y envía refresh_token', () async {
      when(
        () => dio.post<void>('/auth/logout', data: any<Object?>(named: 'data')),
      ).thenAnswer((_) async => logoutResp(204));

      await ds.logout('r-32');

      verify(
        () => dio.post<void>(
          '/auth/logout',
          data: <String, dynamic>{'refresh_token': 'r-32'},
        ),
      ).called(1);
    });

    test(
      '401 → InvalidCredentialsFailure (delega a _mapDioException)',
      () async {
        when(
          () =>
              dio.post<void>('/auth/logout', data: any<Object?>(named: 'data')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/auth/logout'),
            response: logoutResp(401),
            type: DioExceptionType.badResponse,
          ),
        );

        await expectLater(
          ds.logout('r-32'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
      },
    );

    test('timeout → NetworkFailure', () async {
      when(
        () => dio.post<void>('/auth/logout', data: any<Object?>(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/logout'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(ds.logout('r-32'), throwsA(isA<NetworkFailure>()));
    });

    test('500 → UnknownAuthFailure', () async {
      when(
        () => dio.post<void>('/auth/logout', data: any<Object?>(named: 'data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/logout'),
          response: logoutResp(500),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(ds.logout('r-32'), throwsA(isA<UnknownAuthFailure>()));
    });
  });
}
