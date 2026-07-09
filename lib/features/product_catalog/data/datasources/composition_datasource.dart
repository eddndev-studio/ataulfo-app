import 'package:dio/dio.dart';

import '../../domain/entities/composition_job.dart';
import '../../domain/failures/composition_failure.dart';
import '../dto/composition_job_dto.dart';
import '../mappers/composition_mapper.dart';

/// Puerto de datos de la composición de fondos. Las implementaciones lanzan
/// `CompositionFailure` tipadas; nunca DioException cruda.
abstract interface class CompositionDatasource {
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  });
  Future<List<CompositionJob>> listJobs(String productId);
  Future<void> accept(String jobId);
  Future<void> discard(String jobId);
}

class DioCompositionDatasource implements CompositionDatasource {
  DioCompositionDatasource(this._dio);

  final Dio _dio;

  static const String _base = '/workspace/catalog';

  /// Modelo del wire de la calidad premium. El dominio habla de `premium`;
  /// el id concreto del modelo es detalle del contrato y vive solo aquí.
  static const String _premiumModel = 'gemini-3-pro-image';

  @override
  Future<String> compose({
    required String productId,
    required String preset,
    bool premium = false,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_base/products/$productId/compose',
      // Omitir `model` pide la calidad estándar del plan; la clave solo
      // viaja cuando el operador eligió premium.
      data: <String, dynamic>{
        'preset': preset,
        if (premium) 'model': _premiumModel,
      },
    );
    final jobId = res.data?['jobId'];
    if (jobId is! String) throw const FormatException('respuesta sin jobId');
    return jobId;
  });

  @override
  Future<List<CompositionJob>> listJobs(String productId) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/products/$productId/compositions',
    );
    final body = res.data;
    if (body == null) throw const FormatException('body nulo');
    return (body['jobs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CompositionJobDto.fromJson)
        .map(CompositionMapper.dtoToEntity)
        .toList(growable: false);
  });

  @override
  Future<void> accept(String jobId) => _guard(() async {
    await _dio.post<Map<String, dynamic>>('$_base/compositions/$jobId/accept');
  });

  @override
  Future<void> discard(String jobId) => _guard(() async {
    await _dio.post<Map<String, dynamic>>('$_base/compositions/$jobId/discard');
  });

  // ── Traducción de errores ───────────────────────────────────────────────

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on CompositionFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownCompositionFailure();
    } on TypeError {
      throw const UnknownCompositionFailure();
    }
  }

  CompositionFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const CompositionTimeoutFailure();
      case DioExceptionType.connectionError:
        return const CompositionNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 422) {
          return CompositionRejectedFailure(
            _copyFor(_rejectionCopy, e.response?.data),
          );
        }
        if (status == 409) {
          return CompositionConflictFailure(
            _copyFor(_conflictCopy, e.response?.data),
          );
        }
        if (status == 404) return const CompositionNotFoundFailure();
        // 503 = el dominio de imagen no está disponible; se distingue del
        // 5xx genérico ANTES del rango para dar el copy de «más tarde».
        if (status == 503) return const CompositionUnavailableFailure();
        if (status >= 500 && status < 600) {
          return const CompositionServerFailure();
        }
        return const UnknownCompositionFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownCompositionFailure();
    }
  }

  /// Copy es-MX por código estable de rechazo 422 (`{"error": code}`). El
  /// wire manda códigos, no frases: esta es la única frontera que los conoce
  /// y los traduce. Un código fuera del mapa degrada a null (la UI cae a su
  /// copy genérico); JAMÁS se muestra el código crudo.
  static const Map<String, String> _rejectionCopy = <String, String>{
    'no_source_image':
        'El producto no tiene foto original. Ponle una imagen primero.',
    'invalid_preset': 'Ese fondo no está disponible. Elige otro.',
    'quota_exceeded': 'Alcanzaste el tope de imágenes de tu plan este mes.',
    'model_not_allowed': 'La calidad premium requiere plan Pro o Business.',
    'subscription_inactive': 'Tu suscripción tiene un pago pendiente.',
    'trial_expired': 'Tu periodo de prueba terminó.',
    'media_not_found': 'La imagen ya no está en la galería.',
  };

  /// Copy es-MX por código de conflicto 409 (la acción no procede en el
  /// estado actual del job). Mismo contrato de degradación que el 422.
  static const Map<String, String> _conflictCopy = <String, String>{
    'not_done': 'Todavía no está lista; espera el resultado.',
    'in_flight': 'Todavía se está creando; espera el resultado.',
    'media_in_use':
        'El producto usa esta imagen; cámbiala antes de descartarla.',
  };

  String? _copyFor(Map<String, String> copy, dynamic data) {
    if (data is! Map) return null;
    final code = data['error'];
    if (code is! String) return null;
    return copy[code];
  }
}
