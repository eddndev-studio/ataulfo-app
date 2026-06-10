import 'package:dio/dio.dart';

import '../../domain/entities/preview_item.dart';
import '../../domain/failures/trainer_failure.dart';
import '../dto/preview_dtos.dart';
import 'failure_mapper.dart';

/// Puerto de datos del preview sandbox. POST síncrono (el turno completo
/// del bot); GET rehidrata el transcript vivo; DELETE resetea la sesión.
/// 503 ⇒ sandbox sin cablear en el server (TrainerUnavailableFailure).
abstract interface class PreviewDatasource {
  Future<PreviewTurn> sendMessage({
    required String templateId,
    required String content,
  });

  Future<List<PreviewItem>> transcript({required String templateId});

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
      );
      final body = res.data;
      final items = body?['items'];
      if (items is! List<dynamic>) throw const TrainerUnknownFailure();
      return PreviewTurn(
        items: PreviewItemDto.listFromJson(items),
        iterations: body?['iterations'] is int ? body!['iterations'] as int : 0,
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
  Future<List<PreviewItem>> transcript({required String templateId}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$templateId/preview/messages',
      );
      final items = res.data?['items'];
      if (items is! List<dynamic>) throw const TrainerUnknownFailure();
      return PreviewItemDto.listFromJson(items);
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
  Future<void> reset({required String templateId}) async {
    try {
      await _dio.delete<void>('/templates/$templateId/preview');
    } on DioException catch (e) {
      throw mapTrainerDioException(e);
    }
  }
}
