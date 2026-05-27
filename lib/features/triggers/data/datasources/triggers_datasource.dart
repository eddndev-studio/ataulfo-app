import 'package:dio/dio.dart';

import '../../domain/entities/trigger.dart';
import '../../domain/failures/triggers_failure.dart';
import '../dto/trigger_dto.dart';
import '../mappers/triggers_mapper.dart';

/// Puerto de datos para los endpoints de Trigger (S11).
///
/// Las implementaciones lanzan `TriggersFailure` tipadas; nunca
/// DioException cruda. El repositorio y el bloc consumen failures de
/// dominio. Drift de contrato del backend (un enum nuevo) NO se mapea a
/// una failure — propaga el `ArgumentError` del enum fail-loud.
abstract interface class TriggersDatasource {
  /// `GET /templates/:templateId/triggers` org-scoped. Devuelve
  /// `{items:[...]}`. El AuthInterceptor inyecta el Bearer. RBAC del
  /// backend rechaza con 403 si el rol no alcanza. 404 si la Template
  /// padre no existe en la org del operador (o fue borrada). Lista
  /// vacía es válida (template sin disparadores configurados todavía).
  Future<List<Trigger>> listTriggers(String templateId);
}

class DioTriggersDatasource implements TriggersDatasource {
  DioTriggersDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Trigger>> listTriggers(String templateId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$templateId/triggers',
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownTriggersFailure();
      }
      return TriggersMapper.listToTriggers(ListTriggersResp.fromJson(body));
    } on TriggersFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownTriggersFailure();
    } on TypeError {
      // `cast<Map<String,dynamic>>` puede romper si el wire mete un tipo
      // inesperado dentro de items; el contrato dice array de objetos.
      throw const UnknownTriggersFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de TriggersFailure.
  /// Espejo fiel del `_mapDioException` de FlowsDatasource (sin mapeos
  /// de 422 — no hay mutaciones en el slice read-only).
  TriggersFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TriggersTimeoutFailure();
      case DioExceptionType.connectionError:
        return const TriggersNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const TriggersForbiddenFailure();
        if (status == 404) return const TriggersNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const TriggersServerFailure();
        }
        return const UnknownTriggersFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownTriggersFailure();
    }
  }
}
