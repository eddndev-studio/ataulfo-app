import 'package:dio/dio.dart';

import '../../domain/entities/pa_conversation.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_models.dart';
import '../../domain/failures/pa_failure.dart';
import '../dto/pa_dtos.dart';
import 'pa_failure_mapper.dart';
import 'pa_turn_timeout.dart';

/// Puerto de datos del chat con el asistente de plataforma (org-scoped). El
/// POST de mensaje es SÍNCRONO: corre el turno completo del motor y devuelve
/// el assistant final (puede tardar — el caller muestra el indicador en vivo).
abstract interface class PlatformAgentDatasource {
  Future<PaConversation> createConversation({String title});

  Future<List<PaConversation>> listConversations();

  /// Página DESC del historial; cursor vacío ⇒ primera página.
  Future<PaMessagesPage> listMessages({
    required String conversationId,
    String cursor,
    int limit,
  });

  /// Corre un turno: persiste el user message y devuelve el assistant final.
  /// 502 ⇒ PaEngineFailure (el motor no produjo turno). `model` null ⇒ se
  /// omite del body y el server corre con su default.
  Future<PaMessage> sendMessage({
    required String conversationId,
    required String content,
    String? model,
  });

  /// Allowlist de modelos del agente + default de la plataforma. El caller la
  /// trata como best-effort: cualquier fallo oculta el selector.
  Future<PaModels> listModels();
}

class DioPlatformAgentDatasource implements PlatformAgentDatasource {
  DioPlatformAgentDatasource(this._dio);

  final Dio _dio;

  static const String _base = '/platform-agent/conversations';

  @override
  Future<PaConversation> createConversation({String title = ''}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _base,
        data: <String, dynamic>{if (title.isNotEmpty) 'title': title},
      );
      final body = res.data;
      if (body == null) throw const PaUnknownFailure();
      return PaConversationDto.fromJson(body).toEntity();
    } on PaFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapPlatformAgentDioException(e);
    } on FormatException {
      throw const PaUnknownFailure();
    } on TypeError {
      throw const PaUnknownFailure();
    }
  }

  @override
  Future<List<PaConversation>> listConversations() async {
    try {
      final res = await _dio.get<List<dynamic>>(_base);
      final body = res.data;
      if (body == null) throw const PaUnknownFailure();
      return body
          .map(
            (e) => PaConversationDto.fromJson(
              e as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList(growable: false);
    } on PaFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapPlatformAgentDioException(e);
    } on FormatException {
      throw const PaUnknownFailure();
    } on TypeError {
      throw const PaUnknownFailure();
    }
  }

  @override
  Future<PaMessagesPage> listMessages({
    required String conversationId,
    String cursor = '',
    int limit = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/$conversationId/messages',
        queryParameters: <String, dynamic>{
          if (cursor.isNotEmpty) 'cursor': cursor,
          if (limit > 0) 'limit': '$limit',
        },
      );
      final body = res.data;
      final messages = body?['messages'];
      if (messages is! List<dynamic>) throw const PaUnknownFailure();
      return PaMessagesPage(
        messages: messages
            .map(
              (e) =>
                  PaMessageDto.fromJson(e as Map<String, dynamic>).toEntity(),
            )
            .toList(growable: false),
        nextCursor: body?['next_cursor'] is String
            ? body!['next_cursor'] as String
            : '',
      );
    } on PaFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapPlatformAgentDioException(e);
    } on FormatException {
      throw const PaUnknownFailure();
    } on TypeError {
      throw const PaUnknownFailure();
    }
  }

  @override
  Future<PaMessage> sendMessage({
    required String conversationId,
    required String content,
    String? model,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/$conversationId/messages',
        data: <String, dynamic>{'content': content, 'model': ?model},
        options: Options(receiveTimeout: paTurnReceiveTimeout),
      );
      final body = res.data;
      if (body == null) throw const PaUnknownFailure();
      return PaMessageDto.fromJson(body).toEntity();
    } on PaFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapPlatformAgentDioException(e);
    } on FormatException {
      throw const PaUnknownFailure();
    } on TypeError {
      throw const PaUnknownFailure();
    }
  }

  @override
  Future<PaModels> listModels() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/platform-agent/models',
      );
      final body = res.data;
      if (body == null) throw const PaUnknownFailure();
      return PaModelsDto.fromJson(body).toEntity();
    } on PaFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapPlatformAgentDioException(e);
    } on FormatException {
      throw const PaUnknownFailure();
    } on TypeError {
      throw const PaUnknownFailure();
    }
  }
}
