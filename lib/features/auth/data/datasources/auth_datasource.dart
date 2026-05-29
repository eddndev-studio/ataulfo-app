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
