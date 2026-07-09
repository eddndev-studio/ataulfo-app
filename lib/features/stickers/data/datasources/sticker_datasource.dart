import 'package:dio/dio.dart';

import '../../domain/entities/sticker_job.dart';
import '../../domain/failures/sticker_failure.dart';
import '../dto/sticker_job_dto.dart';
import '../mappers/sticker_mapper.dart';

/// Puerto de datos de los stickers de la org (`/workspace/stickers`, ADMIN+).
/// Las impls lanzan `StickerFailure` tipadas; nunca DioException cruda.
abstract interface class StickerDatasource {
  Future<List<StickerJob>> list();

  /// Encola la generación de un sticker para el motivo; devuelve el jobId.
  Future<String> generate(String motif);
}

class DioStickerDatasource implements StickerDatasource {
  DioStickerDatasource(this._dio);

  final Dio _dio;

  static const String _base = '/workspace/stickers';

  @override
  Future<List<StickerJob>> list() => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(_base);
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return (body['jobs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StickerJobDto.fromJson)
        .map(StickerMapper.dtoToEntity)
        .toList(growable: false);
  });

  @override
  Future<String> generate(String motif) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/generate',
      data: <String, dynamic>{'motif': motif},
    );
    final jobId = res.data?['jobId'];
    if (jobId is! String) throw const FormatException('respuesta sin jobId');
    return jobId;
  });

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on StickerFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const StickerUnknownFailure();
    } on TypeError {
      throw const StickerUnknownFailure();
    }
  }

  StickerFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const StickerNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 422) {
          return StickerRejectedFailure(_copyFor(e.response?.data));
        }
        // 503 = el dominio de imagen no está disponible; se distingue del 5xx
        // genérico ANTES del rango para dar el copy de «más tarde».
        if (status == 503) return const StickerUnavailableFailure();
        if (status >= 500 && status < 600) return const StickerServerFailure();
        return const StickerUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const StickerUnknownFailure();
    }
  }

  /// Copy es-MX por código estable de rechazo 422 (`{"error": code}`). El wire
  /// manda códigos, no frases: esta es la única frontera que los conoce. Un
  /// código fuera del mapa degrada a null (la UI cae a su copy genérico);
  /// JAMÁS se muestra el código crudo.
  static const Map<String, String> _rejectionCopy = <String, String>{
    'invalid_motif': 'Ese motivo no está disponible. Elige otro.',
    'quota_exceeded': 'Alcanzaste el tope de imágenes de tu plan este mes.',
    'model_not_allowed': 'Tu plan no permite generar este sticker.',
    'subscription_inactive': 'Tu suscripción tiene un pago pendiente.',
    'trial_expired': 'Tu periodo de prueba terminó.',
  };

  String? _copyFor(dynamic data) {
    if (data is! Map) return null;
    final code = data['error'];
    if (code is! String) return null;
    return _rejectionCopy[code];
  }
}
