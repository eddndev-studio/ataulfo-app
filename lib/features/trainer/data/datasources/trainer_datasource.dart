import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';
import '../../domain/failures/trainer_failure.dart';
import '../dto/trainer_dtos.dart';
import 'failure_mapper.dart';
import 'turn_timeout.dart';

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
  /// `model` es la elección del operador (allowlist del entrenador); null
  /// se omite del body y el server corre con su default. 422 si el id
  /// quedó fuera de la allowlist (app vieja vs server nuevo).
  Future<TrainerMessage> sendMessage({
    required String templateId,
    required String conversationId,
    required String content,
    String? model,
    List<String> attachments = const <String>[],
  });

  /// Sube un adjunto del hilo (multipart). La ref devuelta es la moneda
  /// que el POST de mensaje manda; el server valida pertenencia.
  Future<TrainerAttachment> uploadAttachment({
    required String templateId,
    required Uint8List bytes,
    required String filename,
  });

  /// Allowlist de modelos del entrenador + default de la plataforma. El
  /// caller la trata como best-effort: cualquier fallo oculta el selector.
  Future<TrainerModels> listModels({required String templateId});

  /// Aborta el turno de chat en vuelo (si lo hay): el `sendMessage` colgado
  /// lanza un fallo de cancelación. No-op si no hay turno corriendo.
  void cancelInFlight();
}

class DioTrainerDatasource implements TrainerDatasource {
  DioTrainerDatasource(this._dio);

  final Dio _dio;

  /// Token del turno de chat en vuelo: lo arma `sendMessage` y lo dispara
  /// `cancelInFlight`. Uno a la vez (un turno por hilo).
  CancelToken? _inFlight;

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
    String? model,
    List<String> attachments = const <String>[],
  }) async {
    final token = CancelToken();
    _inFlight = token;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '${_base(templateId)}/$conversationId/messages',
        data: <String, dynamic>{
          'content': content,
          'model': ?model,
          if (attachments.isNotEmpty) 'attachments': attachments,
        },
        options: Options(receiveTimeout: turnReceiveTimeout),
        cancelToken: token,
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
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }

  @override
  void cancelInFlight() => _inFlight?.cancel();

  @override
  Future<TrainerAttachment> uploadAttachment({
    required String templateId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates/$templateId/trainer/attachments',
        data: FormData.fromMap(<String, dynamic>{
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
      final body = res.data;
      if (body == null) throw const TrainerUnknownFailure();
      return TrainerAttachmentDto.fromJson(body).toEntity();
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
  Future<TrainerModels> listModels({required String templateId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$templateId/trainer/models',
      );
      final body = res.data;
      if (body == null) throw const TrainerUnknownFailure();
      return TrainerModelsDto.fromJson(body).toEntity();
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
