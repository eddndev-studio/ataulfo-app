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

  /// `POST /templates/:templateId/flows` body `{name, cooldownMs:0,
  /// usageLimit:0, excludesFlows:[]}`. Defaults silenciosos para los
  /// gates: `cooldownMs:0` = sin cooldown, `usageLimit:0` = sin límite,
  /// `excludesFlows:[]` = sin exclusiones. Los gates se ajustan después
  /// en el Settings tab del editor de flow.
  ///
  /// 201 con el flow completo (incluye `version:1` inicial). 422 si el
  /// nombre rompe la validación del dominio → `FlowsInvalidCreateFailure`.
  /// 403 si el rol no alcanza (CRUD de Flow = ADMIN+). 404 si la
  /// Template padre no existe en la org del operador.
  Future<Flow> createFlow({required String templateId, required String name});
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

  @override
  Future<Flow> createFlow({
    required String templateId,
    required String name,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates/$templateId/flows',
        data: <String, dynamic>{
          'name': name,
          // Defaults silenciosos: el editor del flow ajusta luego.
          'cooldownMs': 0,
          'usageLimit': 0,
          'excludesFlows': <String>[],
        },
      );
      final body = res.data;
      if (body == null) {
        throw const UnknownFlowsFailure();
      }
      return FlowsMapper.flowRespToEntity(FlowResp.fromJson(body));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapMutationDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
  }

  /// Traduce DioException de una mutación. Diferencia respecto a
  /// `_mapDioException`: 422 ⇒ `FlowsInvalidCreateFailure` (en lectura
  /// sería UnknownFlowsFailure — 422 sólo aparece en mutaciones).
  FlowsFailure _mapMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const FlowsInvalidCreateFailure();
    }
    return _mapDioException(e);
  }

  /// Traduce DioException a la jerarquía sellada de FlowsFailure.
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
