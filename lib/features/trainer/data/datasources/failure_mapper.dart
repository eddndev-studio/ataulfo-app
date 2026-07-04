import 'package:dio/dio.dart';

import '../../domain/failures/trainer_failure.dart';

/// Mapeo único DioException → TrainerFailure para las tres superficies del
/// entrenador (workspace, hilos, preview): mismo wire, mismo contrato de
/// errores (409 CAS/duplicado, 422 dominio, 502 motor, 503 sin cablear).
TrainerFailure mapTrainerDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TrainerTimeoutFailure();
    case DioExceptionType.connectionError:
      return const TrainerNetworkFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      if (status == 403) return const TrainerForbiddenFailure();
      if (status == 404) return const TrainerNotFoundFailure();
      if (status == 409) return const TrainerConflictFailure();
      if (status == 413) return const TrainerAttachmentTooLargeFailure();
      if (status == 415) return const TrainerAttachmentUnsupportedFailure();
      if (status == 422) return const TrainerValidationFailure();
      if (status == 502) return const TrainerEngineFailure();
      if (status == 503) return const TrainerUnavailableFailure();
      if (status >= 500 && status < 600) return const TrainerServerFailure();
      return const TrainerUnknownFailure();
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const TrainerUnknownFailure();
  }
}
