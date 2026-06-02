import 'package:dio/dio.dart';

import '../../domain/entities/connect_link.dart';
import '../../domain/entities/session_status.dart';
import '../../domain/failures/bots_failure.dart';
import '../dto/connect_token_dto.dart';
import '../dto/session_state_dto.dart';

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

  /// `POST /bots/:id/clear-conversations` ⇒ 204. Purga messages/sessions/
  /// executions/labels/dedupe del bot. EXIGE `paused=true`: 409 `ErrBotNotPaused`
  /// → `BotsNotPausedFailure`. Idempotente sobre cero filas.
  Future<void> clearConversations(String botId);

  /// `POST /bots/:id/reset-sessions` ⇒ 204. Invalida el handshake Signal sin
  /// perder el pareado (útil tras `Bad MAC`). EXIGE `paused=true`: 409
  /// `ErrBotNotPaused` → `BotsNotPausedFailure`.
  Future<void> resetSessions(String botId);

  /// `POST /bots/:id/wipe-credentials` ⇒ 204 (idempotente). Destruye las
  /// credenciales persistidas del dispositivo: el bot re-parea desde cero
  /// (nuevo QR). NO gateado por `paused`; su 409 (org ausente) NO es NotPaused.
  Future<void> wipeCredentials(String botId);

  /// `GET /bots/:id/session` ⇒ 200 `{state, qr?{code}}`. Estado vivo de la
  /// sesión; el `qr` SÓLO viene en PAIRING. "No corre" = `200 + DISCONNECTED`
  /// (NO es error). Estado desconocido en el wire → `UnknownBotsFailure`.
  Future<SessionStatus> getSessionState(String botId);
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

  @override
  Future<void> clearConversations(String botId) async {
    try {
      await _dio.post<void>('/bots/$botId/clear-conversations');
    } on DioException catch (e) {
      throw _mapDioException(e, notPausedConflict: true);
    }
  }

  @override
  Future<void> resetSessions(String botId) async {
    try {
      await _dio.post<void>('/bots/$botId/reset-sessions');
    } on DioException catch (e) {
      throw _mapDioException(e, notPausedConflict: true);
    }
  }

  @override
  Future<void> wipeCredentials(String botId) async {
    try {
      await _dio.post<void>('/bots/$botId/wipe-credentials');
    } on DioException catch (e) {
      // Sin flag: el wipe no gatea paused, así que su 409 colapsa a genérico.
      throw _mapDioException(e);
    }
  }

  @override
  Future<SessionStatus> getSessionState(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bots/$botId/session');
      final body = res.data;
      if (body == null) {
        throw const UnknownBotsFailure();
      }
      return SessionStateResp.fromJson(body).toDomain();
    } on BotsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBotsFailure();
    } on ArgumentError {
      // SessionState.fromWire fail-loud ante un estado desconocido.
      throw const UnknownBotsFailure();
    } on TypeError {
      throw const UnknownBotsFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de BotsFailure. Mismo patrón
  /// que `DioBotsDatasource._mapDioException`; sin caso 422 (los endpoints de
  /// sesión no validan body).
  ///
  /// `notPausedConflict` rige el 409 POR-ENDPOINT: en clear/reset un 409 es
  /// `ErrBotNotPaused` (`BotsNotPausedFailure`); en los demás verbos de sesión
  /// el 409 (org activa ausente) colapsa a genérico — el operador no acciona
  /// distinto sin más contexto.
  BotsFailure _mapDioException(
    DioException e, {
    bool notPausedConflict = false,
  }) {
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
        if (status == 409 && notPausedConflict) {
          return const BotsNotPausedFailure();
        }
        if (status >= 500 && status < 600) return const BotsServerFailure();
        return const UnknownBotsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownBotsFailure();
    }
  }
}
