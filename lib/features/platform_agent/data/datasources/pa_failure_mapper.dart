import 'package:dio/dio.dart';

import '../../domain/failures/pa_failure.dart';

/// Mapeo único DioException → PaFailure para la superficie del asistente de
/// plataforma (409 conflicto de versión, 422 dominio, 502 motor, 503 sin
/// cablear).
PaFailure mapPlatformAgentDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const PaTimeoutFailure();
    case DioExceptionType.connectionError:
      return const PaNetworkFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      if (status == 403) return const PaForbiddenFailure();
      if (status == 404) return const PaNotFoundFailure();
      if (status == 409) return const PaConflictFailure();
      if (status == 422) return const PaValidationFailure();
      if (status == 502) return const PaEngineFailure();
      if (status == 503) return const PaUnavailableFailure();
      if (status >= 500 && status < 600) return const PaServerFailure();
      return const PaUnknownFailure();
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const PaUnknownFailure();
  }
}
