import 'package:dio/dio.dart';

import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/identity.dart';
import '../../domain/failures/auth_failure.dart';
import '../dto/login_dto.dart';
import '../mappers/auth_mapper.dart';

/// Puerto de datos para los endpoints de autenticación de S02.
///
/// Las implementaciones lanzan `AuthFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class AuthDatasource {
  Future<AuthTokens> login({required String email, required String password});

  /// Canjea un refresh por un par nuevo (S02 RF#3: rotación por familia).
  /// 401 ⇒ `InvalidCredentialsFailure` — el backend no distingue refresh
  /// expirado de familia revocada por fuga; el cliente trata ambos como
  /// "sesión inválida, re-login".
  Future<AuthTokens> refresh(String refreshToken);

  /// Devuelve la identidad derivada del access token (S02 `/auth/me`).
  /// Stateless: el backend no golpea BD; los claims del JWT son la fuente
  /// de verdad. Bearer lo inyecta el interceptor; aquí no se gestiona.
  Future<Identity> me();

  /// Revoca la familia del refresh dado (S02 RF#4). El backend responde
  /// 204 sin body. Requiere Bearer válido (lo inyecta el interceptor);
  /// si el access caducó, el flujo de refresh transparente lo renueva
  /// antes del retry.
  Future<void> logout(String refreshToken);

  /// Alta de cuenta (`POST /auth/register`). El backend crea User + org
  /// personal + Membership OWNER y devuelve el par de tokens (201). 409 ⇒
  /// email ya registrado; 400 ⇒ contraseña débil.
  Future<AuthTokens> register({
    required String email,
    required String password,
  });

  /// Canjea el token de verificación de email (`POST /auth/verify-email`).
  /// 404 ⇒ token inexistente/consumido; 410 ⇒ expirado. La respuesta indica
  /// si la cuenta ya estaba verificada (re-canje idempotente del enlace).
  Future<VerifyEmailResp> verifyEmail(String token);

  /// Solicita el correo de reset (`POST /auth/forgot-password`). El backend
  /// responde siempre 204 (no revela si el email existe). Público: no exige
  /// Bearer.
  Future<void> forgotPassword(String email);

  /// Canjea el token de reset y fija la nueva contraseña
  /// (`POST /auth/reset-password`). 404 ⇒ token inexistente; 410 ⇒ expirado
  /// o ya usado; 400 ⇒ contraseña débil. Público: no exige Bearer.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Cambia la org activa de la sesión (`POST /auth/switch-org`). Devuelve un
  /// par de tokens nuevo con la org elegida en los claims. 403 ⇒ el usuario
  /// no es miembro de esa org.
  Future<AuthTokens> switchOrg(String orgId);

  /// Crea una organización (`POST /auth/organizations`). Devuelve un par nuevo
  /// con la org creada ya activa, igual que el switch-org.
  Future<AuthTokens> createOrganization(String name);

  /// Renombra la organización activa (`PATCH /workspace/organization`). 204 al
  /// aplicar; no devuelve tokens.
  Future<void> renameOrganization(String name);

  /// Acepta una invitación pendiente (`POST /auth/invitations/accept`). El
  /// backend responde 204; la nueva membership requiere un switch-org
  /// explícito. 404 ⇒ invitación inexistente/consumida; 409 ⇒ email de la
  /// invitación distinto al de la sesión, o ya miembro de esa org.
  Future<void> acceptInvitation(String token);

  /// Reenvía el correo de verificación al email de la sesión
  /// (`POST /auth/resend-verification`). Requiere Bearer (lo inyecta el
  /// interceptor); sin body. 204 al encolar.
  Future<void> resendVerification();
}

/// Implementación contra dio. Se inyecta una instancia ya configurada con
/// `baseUrl` apuntando al API de ataulfo-go; este datasource no toca
/// configuración global.
class DioAuthDatasource implements AuthDatasource {
  DioAuthDatasource(this._dio);

  final Dio _dio;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final req = LoginReq(email: email, password: password);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: req.toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.tokenRespToEntity(TokenResp.fromJson(body));
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh_token': refreshToken},
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.tokenRespToEntity(TokenResp.fromJson(body));
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<Identity> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/auth/me');
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.meRespToEntity(MeResp.fromJson(body));
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: <String, dynamic>{'refresh_token': refreshToken},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<AuthTokens> register({
    required String email,
    required String password,
  }) async {
    final req = RegisterReq(email: email, password: password);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: req.toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.tokenRespToEntity(TokenResp.fromJson(body));
    } on DioException catch (e) {
      throw _mapStatus(e, <int, AuthFailure>{
        409: const EmailTakenFailure(),
        400: const WeakPasswordFailure(),
      });
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<VerifyEmailResp> verifyEmail(String token) async {
    final req = VerifyEmailReq(token: token);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: req.toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return VerifyEmailResp.fromJson(body);
    } on DioException catch (e) {
      throw _mapStatus(e, <int, AuthFailure>{
        404: const InvalidTokenFailure(),
        410: const ExpiredTokenFailure(),
      });
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    final req = ForgotPasswordReq(email: email);
    try {
      await _dio.post<void>('/auth/forgot-password', data: req.toJson());
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final req = ResetPasswordReq(token: token, newPassword: newPassword);
    try {
      await _dio.post<void>('/auth/reset-password', data: req.toJson());
    } on DioException catch (e) {
      throw _mapStatus(e, <int, AuthFailure>{
        404: const InvalidTokenFailure(),
        410: const ExpiredTokenFailure(),
        400: const WeakPasswordFailure(),
      });
    }
  }

  @override
  Future<AuthTokens> switchOrg(String orgId) async {
    final req = SwitchOrgReq(orgId: orgId);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/switch-org',
        data: req.toJson(),
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.tokenRespToEntity(TokenResp.fromJson(body));
    } on DioException catch (e) {
      throw _mapStatus(e, <int, AuthFailure>{403: const NotMemberFailure()});
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<AuthTokens> createOrganization(String name) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/organizations',
        data: <String, dynamic>{'name': name},
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownAuthFailure();
      }
      return AuthMapper.tokenRespToEntity(TokenResp.fromJson(body));
    } on DioException catch (e) {
      // 422 (nombre inválido) cae al genérico: la pantalla valida no-vacío, así
      // que es defensa de borde y no merece variante propia en el sellado.
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownAuthFailure();
    }
  }

  @override
  Future<void> renameOrganization(String name) async {
    try {
      await _dio.patch<void>(
        '/workspace/organization',
        data: <String, dynamic>{'name': name},
      );
    } on DioException catch (e) {
      // 403 (no ADMIN) y 422 (nombre inválido) son defensa de borde — el gate
      // es cosmético y la pantalla valida — y caen al genérico.
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> acceptInvitation(String token) async {
    final req = AcceptInvitationReq(token: token);
    try {
      await _dio.post<void>('/auth/invitations/accept', data: req.toJson());
    } on DioException catch (e) {
      // El backend responde 409 desnudo para ambos casos (email distinto Y
      // ya miembro) sin discriminador en el body; se mapea al más accionable
      // (re-login con la cuenta correcta de la invitación).
      throw _mapStatus(e, <int, AuthFailure>{
        404: const InvalidTokenFailure(),
        409: const EmailMismatchFailure(),
      });
    }
  }

  @override
  Future<void> resendVerification() async {
    try {
      await _dio.post<void>('/auth/resend-verification');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Mapea un `DioException` a una variante de AuthFailure conocida por
  /// endpoint: para un `badResponse` con status en [overrides], devuelve la
  /// variante específica; cualquier otro caso (red, status no contemplado)
  /// delega en el mapper genérico. Concentra el "status → variante" por
  /// método sin duplicar el manejo de red/timeouts.
  AuthFailure _mapStatus(DioException e, Map<int, AuthFailure> overrides) {
    if (e.type == DioExceptionType.badResponse) {
      final specific = overrides[e.response?.statusCode];
      if (specific != null) return specific;
    }
    return _mapDioException(e);
  }

  /// Traduce DioException a la jerarquía sellada de AuthFailure.
  ///
  /// El catch del datasource concentra la traducción en un solo punto:
  /// el llamador nunca decide entre status y exception type.
  AuthFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return const InvalidCredentialsFailure();
        if (status == 429) return const RateLimitedFailure();
        return const UnknownAuthFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownAuthFailure();
    }
  }
}
