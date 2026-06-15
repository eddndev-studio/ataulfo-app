import 'package:dio/dio.dart';

import '../../domain/failures/labels_failure.dart';

/// Traduce un `DioException` a una `LabelsFailure` tipada. Compartido por los
/// datasources del catálogo (`/labels`) y de la aplicación por chat
/// (`/sessions/.../labels`): ambos hablan con el mismo dominio de errores HTTP.
LabelsFailure mapLabelsDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const LabelsTimeoutFailure();
    case DioExceptionType.connectionError:
      return const LabelsNetworkFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      if (status == 403) return const LabelsForbiddenFailure();
      if (status == 404) return const LabelsNotFoundFailure();
      if (status == 409) return const LabelsDuplicateNameFailure();
      if (status == 422) return const LabelsValidationFailure();
      if (status >= 500 && status < 600) {
        return const LabelsServerFailure();
      }
      return const LabelsUnknownFailure();
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const LabelsUnknownFailure();
  }
}
