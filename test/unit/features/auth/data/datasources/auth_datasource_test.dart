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

  Response<Map<String, dynamic>> jsonResp(
    String path,
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );

  DioException badResponse(String path, int status) => DioException(
    requestOptions: RequestOptions(path: path),
    response: jsonResp(path, status),
    type: DioExceptionType.badResponse,
  );

  Map<String, dynamic> tokenBody() => <String, dynamic>{
    'access_token': 'a.b.c',
    'refresh_token': 'r-32',
    'token_type': 'Bearer',
    'expires_in': 900,
  };

  const tokens = AuthTokens(
    accessToken: 'a.b.c',
    refreshToken: 'r-32',
    tokenType: 'Bearer',
    expiresInSeconds: 900,
  );

  group('DioAuthDatasource.register', () {
    test('201 con par de tokens → AuthTokens', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => jsonResp('/auth/register', 201, body: tokenBody()),
      );

      final got = await ds.register(
        email: 'new@example.com',
        password: 's3cret-pass',
      );

      expect(got, tokens);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: <String, dynamic>{
            'email': 'new@example.com',
            'password': 's3cret-pass',
          },
        ),
      ).called(1);
    });

    test('409 → EmailTakenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/register', 409));

      await expectLater(
        ds.register(email: 'x@y.z', password: 'p'),
        throwsA(isA<EmailTakenFailure>()),
      );
    });

    test('400 → WeakPasswordFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/register', 400));

      await expectLater(
        ds.register(email: 'x@y.z', password: 'short'),
        throwsA(isA<WeakPasswordFailure>()),
      );
    });

    test('timeout → NetworkFailure (delega al mapper genérico)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.register(email: 'x@y.z', password: 'p'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('500 → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/register', 500));

      await expectLater(
        ds.register(email: 'x@y.z', password: 'p'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });
  });

  group('DioAuthDatasource.verifyEmail', () {
    test('200 con {alreadyVerified} → VerifyEmailResp', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => jsonResp(
          '/auth/verify-email',
          200,
          body: <String, dynamic>{'alreadyVerified': false},
        ),
      );

      final resp = await ds.verifyEmail(
        email: 'op@example.com',
        code: '123456',
      );

      expect(resp.alreadyVerified, isFalse);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: <String, dynamic>{'email': 'op@example.com', 'code': '123456'},
        ),
      ).called(1);
    });

    test('404 → InvalidTokenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/verify-email', 404));

      await expectLater(
        ds.verifyEmail(email: 'op@x.com', code: '000000'),
        throwsA(isA<InvalidTokenFailure>()),
      );
    });

    test('410 → ExpiredTokenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/verify-email', 410));

      await expectLater(
        ds.verifyEmail(email: 'op@x.com', code: '123456'),
        throwsA(isA<ExpiredTokenFailure>()),
      );
    });

    test('body nulo → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => jsonResp('/auth/verify-email', 200));

      await expectLater(
        ds.verifyEmail(email: 'op@x.com', code: '123456'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });

    test('429 → RateLimitedFailure (límite por-IP del canje)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/verify-email', 429));

      await expectLater(
        ds.verifyEmail(email: 'op@x.com', code: '123456'),
        throwsA(isA<RateLimitedFailure>()),
      );
    });
  });

  group('DioAuthDatasource.forgotPassword', () {
    test('204 → completa sin excepción y envía el email', () async {
      when(
        () => dio.post<void>(
          '/auth/forgot-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/auth/forgot-password'),
          statusCode: 204,
        ),
      );

      await ds.forgotPassword('op@example.com');

      verify(
        () => dio.post<void>(
          '/auth/forgot-password',
          data: <String, dynamic>{'email': 'op@example.com'},
        ),
      ).called(1);
    });

    test('timeout → NetworkFailure', () async {
      when(
        () => dio.post<void>(
          '/auth/forgot-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/forgot-password'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.forgotPassword('op@example.com'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('DioAuthDatasource.resetPassword', () {
    test('204 → completa y envía email + code + new_password', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/auth/reset-password'),
          statusCode: 204,
        ),
      );

      await ds.resetPassword(
        email: 'op@example.com',
        code: '123456',
        newPassword: 'n3w-pass',
      );

      verify(
        () => dio.post<void>(
          '/auth/reset-password',
          data: <String, dynamic>{
            'email': 'op@example.com',
            'code': '123456',
            'new_password': 'n3w-pass',
          },
        ),
      ).called(1);
    });

    test(
      '404 → InvalidTokenFailure (código/correo inválido o lockout)',
      () async {
        when(
          () => dio.post<void>(
            '/auth/reset-password',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(badResponse('/auth/reset-password', 404));

        await expectLater(
          ds.resetPassword(email: 'op@x.com', code: '000000', newPassword: 'p'),
          throwsA(isA<InvalidTokenFailure>()),
        );
      },
    );

    test('410 → ExpiredTokenFailure (código caducado o ya usado)', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/reset-password', 410));

      await expectLater(
        ds.resetPassword(email: 'op@x.com', code: '123456', newPassword: 'p'),
        throwsA(isA<ExpiredTokenFailure>()),
      );
    });

    test('400 → WeakPasswordFailure', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/reset-password', 400));

      await expectLater(
        ds.resetPassword(email: 'op@x.com', code: '123456', newPassword: 'sh'),
        throwsA(isA<WeakPasswordFailure>()),
      );
    });

    test('429 → RateLimitedFailure (límite por-IP del canje)', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/reset-password', 429));

      await expectLater(
        ds.resetPassword(email: 'op@x.com', code: '123456', newPassword: 'p'),
        throwsA(isA<RateLimitedFailure>()),
      );
    });
  });

  group('DioAuthDatasource.switchOrg', () {
    test('200 con par de tokens → AuthTokens', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/switch-org',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => jsonResp('/auth/switch-org', 200, body: tokenBody()),
      );

      final got = await ds.switchOrg('o-789');

      expect(got, tokens);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/switch-org',
          data: <String, dynamic>{'org_id': 'o-789'},
        ),
      ).called(1);
    });

    test('403 → NotMemberFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/switch-org',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/switch-org', 403));

      await expectLater(
        ds.switchOrg('o-foreign'),
        throwsA(isA<NotMemberFailure>()),
      );
    });

    test('body nulo → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/switch-org',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => jsonResp('/auth/switch-org', 200));

      await expectLater(
        ds.switchOrg('o-1'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });
  });

  group('DioAuthDatasource.createOrganization', () {
    test('201 con par de tokens → AuthTokens (org nueva activa)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/organizations',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => jsonResp('/auth/organizations', 201, body: tokenBody()),
      );

      final got = await ds.createOrganization('Acme');

      expect(got, tokens);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/organizations',
          data: <String, dynamic>{'name': 'Acme'},
        ),
      ).called(1);
    });

    test('body nulo → UnknownAuthFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/organizations',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer((_) async => jsonResp('/auth/organizations', 201));

      await expectLater(
        ds.createOrganization('Acme'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });

    test('422 (nombre inválido, defensivo) → UnknownAuthFailure', () async {
      // La pantalla valida el nombre no-vacío; el 422 es defensa de borde y se
      // colapsa al genérico sin contaminar el sellado AuthFailure.
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/organizations',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/organizations', 422));

      await expectLater(
        ds.createOrganization('   '),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });
  });

  group('DioAuthDatasource.renameOrganization', () {
    test('204 → completa y envía el nombre por PATCH', () async {
      when(
        () => dio.patch<void>(
          '/workspace/organization',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/workspace/organization'),
          statusCode: 204,
        ),
      );

      await ds.renameOrganization('Nuevo Nombre');

      verify(
        () => dio.patch<void>(
          '/workspace/organization',
          data: <String, dynamic>{'name': 'Nuevo Nombre'},
        ),
      ).called(1);
    });

    test('403 (no ADMIN, defensivo) → UnknownAuthFailure', () async {
      when(
        () => dio.patch<void>(
          '/workspace/organization',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/workspace/organization', 403));

      await expectLater(
        ds.renameOrganization('X'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });

    test('sin conexión → NetworkFailure', () async {
      when(
        () => dio.patch<void>(
          '/workspace/organization',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/workspace/organization'),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        ds.renameOrganization('X'),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('DioAuthDatasource.acceptInvitation', () {
    test('204 → completa y envía el token', () async {
      when(
        () => dio.post<void>(
          '/auth/invitations/accept',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/auth/invitations/accept'),
          statusCode: 204,
        ),
      );

      await ds.acceptInvitation('invite-tok');

      verify(
        () => dio.post<void>(
          '/auth/invitations/accept',
          data: <String, dynamic>{'token': 'invite-tok'},
        ),
      ).called(1);
    });

    test(
      '404 → InvalidTokenFailure (invitación inexistente/consumida)',
      () async {
        when(
          () => dio.post<void>(
            '/auth/invitations/accept',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(badResponse('/auth/invitations/accept', 404));

        await expectLater(
          ds.acceptInvitation('bad'),
          throwsA(isA<InvalidTokenFailure>()),
        );
      },
    );

    test(
      '409 → EmailMismatchFailure (sesión equivocada para la invitación)',
      () async {
        // El backend devuelve 409 desnudo para ambos casos (email distinto Y ya
        // miembro); sin discriminador de body el cliente mapea al caso más
        // accionable (re-login con la cuenta correcta).
        when(
          () => dio.post<void>(
            '/auth/invitations/accept',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(badResponse('/auth/invitations/accept', 409));

        await expectLater(
          ds.acceptInvitation('mismatch'),
          throwsA(isA<EmailMismatchFailure>()),
        );
      },
    );

    test(
      '403 → EmailNotVerifiedFailure (aceptar exige correo verificado)',
      () async {
        when(
          () => dio.post<void>(
            '/auth/invitations/accept',
            data: any<Object?>(named: 'data'),
          ),
        ).thenThrow(badResponse('/auth/invitations/accept', 403));

        await expectLater(
          ds.acceptInvitation('unverified'),
          throwsA(isA<EmailNotVerifiedFailure>()),
        );
      },
    );
  });

  group('DioAuthDatasource.resendVerification', () {
    test(
      '204 → completa sin body (Bearer lo inyecta el interceptor)',
      () async {
        when(() => dio.post<void>('/auth/resend-verification')).thenAnswer(
          (_) async => Response<void>(
            requestOptions: RequestOptions(path: '/auth/resend-verification'),
            statusCode: 204,
          ),
        );

        await ds.resendVerification();

        verify(() => dio.post<void>('/auth/resend-verification')).called(1);
      },
    );

    test('timeout → NetworkFailure', () async {
      when(() => dio.post<void>('/auth/resend-verification')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/resend-verification'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.resendVerification(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('DioAuthDatasource.pendingInvitations', () {
    Response<List<dynamic>> listResp(int status, {List<dynamic>? body}) =>
        Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/auth/invitations/pending'),
          statusCode: status,
          data: body,
        );

    test('200 con filas → lista de PendingInvitation', () async {
      when(
        () => dio.get<List<dynamic>>('/auth/invitations/pending'),
      ).thenAnswer(
        (_) async => listResp(
          200,
          body: <dynamic>[
            <String, dynamic>{
              'id': 'inv-1',
              'org_id': 'o-9',
              'org_name': 'Acme',
              'role': 'WORKER',
              'expires_at': '2026-07-15T00:00:00Z',
            },
          ],
        ),
      );

      final got = await ds.pendingInvitations();

      expect(got, hasLength(1));
      expect(got.first.id, 'inv-1');
      expect(got.first.orgName, 'Acme');
      expect(got.first.role, 'WORKER');
    });

    test(
      '200 con [] (correo sin verificar) → lista vacía, sin fallo',
      () async {
        when(
          () => dio.get<List<dynamic>>('/auth/invitations/pending'),
        ).thenAnswer((_) async => listResp(200, body: <dynamic>[]));

        expect(await ds.pendingInvitations(), isEmpty);
      },
    );

    test('body nulo → UnknownAuthFailure', () async {
      when(
        () => dio.get<List<dynamic>>('/auth/invitations/pending'),
      ).thenAnswer((_) async => listResp(200));

      await expectLater(
        ds.pendingInvitations(),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });

    test('timeout → NetworkFailure', () async {
      when(() => dio.get<List<dynamic>>('/auth/invitations/pending')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/invitations/pending'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.pendingInvitations(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('DioAuthDatasource.acceptPendingInvitation', () {
    test('200 → AcceptedInvitation y envía invitation_id', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => jsonResp(
          '/auth/invitations/accept-pending',
          200,
          body: <String, dynamic>{
            'org_id': 'o-9',
            'org_name': 'Acme',
            'role': 'WORKER',
          },
        ),
      );

      final got = await ds.acceptPendingInvitation('inv-1');

      expect(got.orgName, 'Acme');
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: <String, dynamic>{'invitation_id': 'inv-1'},
        ),
      ).called(1);
    });

    test('403 → EmailNotVerifiedFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/invitations/accept-pending', 403));

      await expectLater(
        ds.acceptPendingInvitation('inv-1'),
        throwsA(isA<EmailNotVerifiedFailure>()),
      );
    });

    test('404 → InvalidTokenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/invitations/accept-pending', 404));

      await expectLater(
        ds.acceptPendingInvitation('inv-x'),
        throwsA(isA<InvalidTokenFailure>()),
      );
    });

    test('409 → AlreadyMemberFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/invitations/accept-pending', 409));

      await expectLater(
        ds.acceptPendingInvitation('inv-1'),
        throwsA(isA<AlreadyMemberFailure>()),
      );
    });

    test('410 → ExpiredTokenFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/invitations/accept-pending',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/invitations/accept-pending', 410));

      await expectLater(
        ds.acceptPendingInvitation('inv-1'),
        throwsA(isA<ExpiredTokenFailure>()),
      );
    });
  });
}
