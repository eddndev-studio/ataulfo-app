import 'package:dio/dio.dart';

import '../../domain/failures/quick_replies_failure.dart';

/// Traduce `DioException` a la jerarquía sellada `QuickRepliesFailure`. Un solo
/// perfil: el recurso es de solo lectura (`GET /bots/{botId}/quick-replies`), sin
/// push a WhatsApp, así que no hay 422/409/502 que mapear.
class QuickRepliesErrors {
  const QuickRepliesErrors._();

  static QuickRepliesFailure read(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const QuickRepliesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const QuickRepliesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const QuickRepliesForbiddenFailure();
        if (status == 404) return const QuickRepliesNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const QuickRepliesServerFailure();
        }
        return const QuickRepliesUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const QuickRepliesUnknownFailure();
    }
  }
}
