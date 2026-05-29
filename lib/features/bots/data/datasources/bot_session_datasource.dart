import 'package:dio/dio.dart';

import '../../domain/entities/connect_link.dart';
import '../../domain/failures/bots_failure.dart';
import '../dto/connect_token_dto.dart';

/// Puerto de datos para el ciclo de vida de la sesión de canal de un Bot y
/// la emisión de enlaces públicos de emparejamiento (S04 RF#7).
///
/// Las implementaciones lanzan `BotsFailure` tipadas; nunca DioException
/// cruda. Comparte la jerarquía de failures con `BotsDatasource`: es el
/// mismo feature y los modos de fallo coinciden (403/404/5xx/red/timeout).
abstract interface class BotSessionDatasource {
  /// `POST /bots/:id/session` ⇒ 202. Arranca la sesión de canal (→ PAIRING).
  Future<void> startSession(String botId);

  /// `DELETE /bots/:id/session` ⇒ 204. La detiene (idempotente en backend).
  Future<void> stopSession(String botId);

  /// `POST /bots/:id/connect-token` ⇒ 201 `{token, expiresAt}`. Emite un
  /// ConnectToken y construye el enlace público a compartir.
  Future<ConnectLink> issueConnectLink(String botId);
}

class DioBotSessionDatasource implements BotSessionDatasource {
  DioBotSessionDatasource(this._dio);

  final Dio _dio;

  @override
  Future<void> startSession(String botId) async {
    try {
      await _dio.post<void>('/bots/$botId/session');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<void> stopSession(String botId) async {
    try {
      await _dio.delete<void>('/bots/$botId/session');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  @override
  Future<ConnectLink> issueConnectLink(String botId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/bots/$botId/connect-token',
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      final dto = ConnectTokenResp.fromJson(body);
      return ConnectLink(url: _connectUrl(dto.token), expiresAt: dto.expiresAt);
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  /// La página pública vive en la raíz del backend (`/connect`), el mismo
  /// origen al que apunta el cliente — por eso se compone desde el baseUrl
  /// del Dio y no de un valor aparte. El token va URL-encoded por defensa
  /// aunque hoy sea base64url (URL-safe): un cambio de codificación del
  /// backend no rompe el enlace.
  String _connectUrl(String token) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/connect?token=${Uri.encodeComponent(token)}';
  }

  /// Traduce DioException a la jerarquía sellada de BotsFailure. Mismo patrón
  /// que `DioBotsDatasource._mapDioException`; sin caso 422 (los endpoints de
  /// sesión no validan body) y el 409 de connect-token —org activa ausente—
  /// colapsa a genérico (el operador no acciona distinto sin más contexto).
  BotsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const BotsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const BotsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const BotsForbiddenFailure();
        if (status == 404) return const BotsNotFoundFailure();
        if (status >= 500 && status < 600) return const BotsServerFailure();
        return const UnknownBotsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownBotsFailure();
    }
  }
}
