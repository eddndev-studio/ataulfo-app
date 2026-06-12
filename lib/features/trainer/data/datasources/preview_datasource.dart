import 'package:dio/dio.dart';

import '../../domain/entities/preview_item.dart';
import '../../domain/failures/trainer_failure.dart';
import '../dto/preview_dtos.dart';
import 'failure_mapper.dart';
import 'turn_timeout.dart';

/// Puerto de datos del preview sandbox. POST corre el turno (síncrono, o
/// inmediato con `pending` cuando la plantilla acumula); GET rehidrata el
/// transcript vivo con el estado de la ventana; DELETE resetea la sesión.
/// 503 ⇒ sandbox sin cablear en el server (TrainerUnavailableFailure).
abstract interface class PreviewDatasource {
  Future<PreviewTurn> sendMessage({
    required String templateId,
    required String content,
  });

  Future<PreviewTranscript> transcript({required String templateId});

  Future<void> reset({required String templateId});
}

class DioPreviewDatasource implements PreviewDatasource {
  DioPreviewDatasource(this._dio);

  final Dio _dio;

  @override
  Future<PreviewTurn> sendMessage({
    required String templateId,
    required String content,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates/$templateId/preview/messages',
        data: <String, dynamic>{'content': content},
        options: Options(receiveTimeout: turnReceiveTimeout),
      );
      final body = res.data;
      final items = body?['items'];
      if (items is! List<dynamic>) throw const TrainerUnknownFailure();
      return PreviewTurn(
        items: PreviewItemDto.listFromJson(items),
        iterations: body?['iterations'] is int ? body!['iterations'] as int : 0,
        pending: body?['pending'] == true,
        windowEndsAt: _windowEndsAt(body),
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
  Future<PreviewTranscript> transcript({required String templateId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$templateId/preview/messages',
      );
      final body = res.data;
      final items = body?['items'];
      if (items is! List<dynamic>) throw const TrainerUnknownFailure();
      return PreviewTranscript(
        items: PreviewItemDto.listFromJson(items),
        pending: body?['pending'] == true,
        windowEndsAt: _windowEndsAt(body),
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

  /// windowEndsAt es aditivo y solo viaja con una ventana viva; ausente o
  /// ilegible ⇒ null (el cliente degrada a poll inmediato).
  static DateTime? _windowEndsAt(Map<String, dynamic>? body) {
    final raw = body?['windowEndsAt'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  Future<void> reset({required String templateId}) async {
    try {
      await _dio.delete<void>('/templates/$templateId/preview');
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    }
  }
}
