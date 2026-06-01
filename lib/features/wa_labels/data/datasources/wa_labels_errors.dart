import 'package:dio/dio.dart';

import '../../domain/failures/wa_labels_failure.dart';

/// Traduce `DioException` a la jerarquía sellada `WaLabelsFailure`. Tres
/// perfiles según el endpoint:
///
///   - [read]: GETs (catálogo, asociaciones, mapeos). 403/404/5xx/red/timeout.
///   - [push]: mutaciones que empujan al cliente WhatsApp (CRUD del catálogo,
///     asociar/desasociar). Añade 422→Invalid, 409→NotConnected, 502→Upstream
///     ANTES de delegar en [read] (que mapearía 502 como 5xx genérico).
///   - [mapping]: set/clear del mapeo a Label interno (NO empuja a WhatsApp).
///     Solo añade 422→Invalid (label inexistente/fuera de org).
class WaLabelsErrors {
  const WaLabelsErrors._();

  static WaLabelsFailure read(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const WaLabelsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const WaLabelsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const WaLabelsForbiddenFailure();
        if (status == 404) return const WaLabelsNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const WaLabelsServerFailure();
        }
        return const WaLabelsUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const WaLabelsUnknownFailure();
    }
  }

  static WaLabelsFailure push(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      final status = e.response?.statusCode ?? 0;
      if (status == 422) return const WaLabelsInvalidFailure();
      if (status == 409) return const WaLabelsNotConnectedFailure();
      if (status == 502) return const WaLabelsUpstreamFailure();
    }
    return read(e);
  }

  static WaLabelsFailure mapping(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const WaLabelsInvalidFailure();
    }
    return read(e);
  }
}
