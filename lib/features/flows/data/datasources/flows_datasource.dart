import 'package:dio/dio.dart';

import '../../domain/entities/flow.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../dto/flow_dto.dart';
import '../dto/step_dto.dart';
import '../mappers/flows_mapper.dart';
import '../mappers/steps_mapper.dart';

/// Puerto de datos para los endpoints de Flow (S11).
///
/// Las implementaciones lanzan `FlowsFailure` tipadas; nunca DioException
/// cruda. El repositorio y el bloc consumen failures de dominio.
abstract interface class FlowsDatasource {
  /// `GET /templates/:templateId/flows` org-scoped. El AuthInterceptor
  /// inyecta el Bearer; aquí no se gestiona. RBAC del backend rechaza
  /// con 403 si el rol no alcanza. 404 si la Template no existe en la
  /// org del operador (o fue borrada).
  Future<List<Flow>> listFlows(String templateId);

  /// `GET /flows/:id` org-scoped. Devuelve sólo la cabecera del flow
  /// (sin steps — los steps viven en `listSteps`). 404 si el flow
  /// no existe en la org del operador.
  Future<Flow> flowById(String id);

  /// `GET /flows/:flowId/steps` org-scoped. Devuelve `{items:[...]}`
  /// ordenado por `order` ASC (el backend lo garantiza en SQL). 404 si
  /// el flow padre no existe en la org.
  Future<List<fdom.Step>> listSteps(String flowId);
}

class DioFlowsDatasource implements FlowsDatasource {
  DioFlowsDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Flow>> listFlows(String templateId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/templates/$templateId/flows',
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownFlowsFailure();
      }
      return FlowsMapper.listToFlows(ListFlowsResp.fromJson(body));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
  }

  @override
  Future<Flow> flowById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/flows/$id');
      final body = res.data;
      if (body == null) {
        throw const UnknownFlowsFailure();
      }
      return FlowsMapper.flowRespToEntity(FlowResp.fromJson(body));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
  }

  @override
  Future<List<fdom.Step>> listSteps(String flowId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/flows/$flowId/steps');
      final body = res.data;
      if (body == null) {
        throw const UnknownFlowsFailure();
      }
      return StepsMapper.listToSteps(ListStepsResp.fromJson(body));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
  }

  /// Traduce DioException a la jerarquía sellada de FlowsFailure. Espejo
  /// fiel del `_mapDioException` de TemplatesDatasource pero sin los
  /// mapeos de 422 (no hay mutaciones en F1).
  FlowsFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const FlowsTimeoutFailure();
      case DioExceptionType.connectionError:
        return const FlowsNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const FlowsForbiddenFailure();
        if (status == 404) return const FlowsNotFoundFailure();
        if (status >= 500 && status < 600) {
          return const FlowsServerFailure();
        }
        return const UnknownFlowsFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const UnknownFlowsFailure();
    }
  }
}
