import 'package:dio/dio.dart';

import '../../domain/entities/entitlement.dart';
import '../../domain/failures/billing_failure.dart';
import '../dto/entitlement_dto.dart';
import '../mappers/entitlement_mapper.dart';

/// Puerto de datos para `GET /workspace/billing`.
///
/// Las implementaciones lanzan `BillingFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class BillingDatasource {
  /// `GET /workspace/billing` — foto de entitlement de la ORG ACTIVA de las
  /// claims (Bearer lo inyecta el interceptor). Viaja bajo workerOnly:
  /// cualquier miembro lee el entitlement de su org.
  Future<Entitlement> fetch();
}

class DioBillingDatasource implements BillingDatasource {
  DioBillingDatasource(this._dio);

  final Dio _dio;

  @override
  Future<Entitlement> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/workspace/billing');
      final body = res.data;
      if (body == null) {
        throw const UnknownBillingFailure();
      }
      final dto = EntitlementDto.fromJson(body);
      return EntitlementMapper.dtoToEntity(dto);
    } on BillingFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownBillingFailure();
    } on TypeError {
      // Defensa contra wires con tipos inesperados; el contrato dice objeto
      // con las claves del entitlement.
      throw const UnknownBillingFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada del feature. 409 y 404 son
  /// los rechazos propios del endpoint (claims sin org activa / org sin
  /// suscripción); sin variante 403 (workerOnly cubre a todo miembro).
  BillingFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const BillingTimeoutFailure();
      case DioExceptionType.connectionError:
        return const BillingNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 409) return const BillingOrgUnresolvedFailure();
        if (status == 404) return const BillingNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const BillingServerFailure();
        }
        return const UnknownBillingFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownBillingFailure();
    }
  }
}
