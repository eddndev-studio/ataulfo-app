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

      final resp = await ds.verifyEmail('verif-tok');

      expect(resp.alreadyVerified, isFalse);
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/verify-email',
          data: <String, dynamic>{'token': 'verif-tok'},
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
        ds.verifyEmail('bad'),
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
        ds.verifyEmail('old'),
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
        ds.verifyEmail('t'),
        throwsA(isA<UnknownAuthFailure>()),
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
    test('204 → completa y envía token + new_password', () async {
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

      await ds.resetPassword(token: 'reset-tok', newPassword: 'n3w-pass');

      verify(
        () => dio.post<void>(
          '/auth/reset-password',
          data: <String, dynamic>{
            'token': 'reset-tok',
            'new_password': 'n3w-pass',
          },
        ),
      ).called(1);
    });

    test('404 → InvalidTokenFailure', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/reset-password', 404));

      await expectLater(
        ds.resetPassword(token: 'bad', newPassword: 'p'),
        throwsA(isA<InvalidTokenFailure>()),
      );
    });

    test('410 → ExpiredTokenFailure (token caducado o ya usado)', () async {
      when(
        () => dio.post<void>(
          '/auth/reset-password',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(badResponse('/auth/reset-password', 410));

      await expectLater(
        ds.resetPassword(token: 'old', newPassword: 'p'),
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
        ds.resetPassword(token: 't', newPassword: 'short'),
        throwsA(isA<WeakPasswordFailure>()),
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
}
