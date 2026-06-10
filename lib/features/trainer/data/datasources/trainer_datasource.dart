import 'package:dio/dio.dart';

import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/failures/trainer_failure.dart';
import '../dto/trainer_dtos.dart';
import 'failure_mapper.dart';

/// Puerto de datos del hilo del entrenador (template-scoped). El POST de
/// mensaje es SÍNCRONO: corre el turno completo del motor y devuelve el
/// assistant final (puede tardar — el caller muestra typing).
abstract interface class TrainerDatasource {
  Future<TrainerConversation> createConversation({
    required String templateId,
    String title,
  });

  Future<List<TrainerConversation>> listConversations({
    required String templateId,
  });

  /// Página DESC del historial; cursor vacío ⇒ primera página.
  Future<TrainerMessagesPage> listMessages({
    required String templateId,
    required String conversationId,
    String cursor,
    int limit,
  });

  /// Corre un turno: persiste el user message y devuelve el assistant
  /// final. 502 ⇒ TrainerEngineFailure (el motor no produjo turno).
  Future<TrainerMessage> sendMessage({
    required String templateId,
    required String conversationId,
    required String content,
  });
}

class DioTrainerDatasource implements TrainerDatasource {
  DioTrainerDatasource(this._dio);

  final Dio _dio;

  String _base(String templateId) =>
      '/templates/$templateId/trainer/conversations';

  @override
  Future<TrainerConversation> createConversation({
    required String templateId,
    String title = '',
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _base(templateId),
        data: <String, dynamic>{if (title.isNotEmpty) 'title': title},
      );
      final body = res.data;
      if (body == null) throw const TrainerUnknownFailure();
      return TrainerConversationDto.fromJson(body).toEntity();
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }

  @override
  Future<List<TrainerConversation>> listConversations({
    required String templateId,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(_base(templateId));
      final body = res.data;
      if (body == null) throw const TrainerUnknownFailure();
      return body
          .map(
            (e) => TrainerConversationDto.fromJson(
              e as Map<String, dynamic>,
            ).toEntity(),
          )
          .toList(growable: false);
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }

  @override
  Future<TrainerMessagesPage> listMessages({
    required String templateId,
    required String conversationId,
    String cursor = '',
    int limit = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '${_base(templateId)}/$conversationId/messages',
        queryParameters: <String, dynamic>{
          if (cursor.isNotEmpty) 'cursor': cursor,
          if (limit > 0) 'limit': '$limit',
        },
      );
      final body = res.data;
      final messages = body?['messages'];
      if (messages is! List<dynamic>) throw const TrainerUnknownFailure();
      return TrainerMessagesPage(
        messages: messages
            .map(
              (e) => TrainerMessageDto.fromJson(
                e as Map<String, dynamic>,
              ).toEntity(),
            )
            .toList(growable: false),
        nextCursor: body?['next_cursor'] is String
            ? body!['next_cursor'] as String
            : '',
      );
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }

  @override
  Future<TrainerMessage> sendMessage({
    required String templateId,
    required String conversationId,
    required String content,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '${_base(templateId)}/$conversationId/messages',
        data: <String, dynamic>{'content': content},
      );
      final body = res.data;
      if (body == null) throw const TrainerUnknownFailure();
      return TrainerMessageDto.fromJson(body).toEntity();
    } on TrainerFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    } on FormatException {
      throw const TrainerUnknownFailure();
    } on TypeError {
      throw const TrainerUnknownFailure();
    }
  }
}
