import 'dart:convert';

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

  /// `POST /flows/:flowId/steps` body crudo del step (sin envelope). El
  /// wire usa `type` en UPPERCASE; los campos opcionales que el dominio
  /// no requiere para el tipo (ej. `mediaRef` en TEXT) viajan como
  /// string vacío.
  ///
  /// 201 con el step creado (incluyendo su id asignado por el backend).
  /// 422 si el body rompe la validación del step
  /// → `FlowsInvalidStepFailure`. 404 si el flow padre no existe en la
  /// org → `FlowsNotFoundFailure`. 403 si el rol no alcanza → `Forbidden`.
  Future<fdom.Step> createStep({
    required String flowId,
    required fdom.StepType type,
    required int order,
    required String content,
    required String mediaRef,
    required int delayMs,
    required int jitterPct,
    required bool aiOnly,
    String? metadataJson,
  });

  /// `PATCH /steps/:stepId` con body **only-changed**: cualquier campo
  /// `null` aquí se OMITE del JSON (el backend trata omitidos como
  /// "preservar"). Mandar `{"content": null}` sería distinto de omitir
  /// `content` — para mantener simetría con el contrato Go (pointers +
  /// omitempty), el datasource no envía null.
  ///
  /// `order` viaja cuando el cliente reordena steps por drag&drop. El
  /// reorder es N×PATCH (uno por step que cambió de posición); sin
  /// UNIQUE en `(flow_id, order)` no requiere two-pass — cada patch
  /// va independiente y el listado posterior se ordena por `order` ASC.
  ///
  /// 200 con el step resultante completo. 422
  /// → `FlowsInvalidStepFailure`. 404 → `FlowsStepNotFoundFailure`
  /// (distinto del NotFound del flow padre: aquí el step en sí no
  /// existe, típicamente por concurrencia con otro operador).
  Future<fdom.Step> patchStep({
    required String stepId,
    String? content,
    int? delayMs,
    int? jitterPct,
    bool? aiOnly,
    int? order,
    String? metadataJson,
  });

  /// `DELETE /steps/:stepId` idempotente. 204 sin body en ambos casos
  /// (existía o no). 404 se trata como éxito (defensa por si llegara —
  /// el backend canónico siempre responde 204). 403 → Forbidden.
  Future<void> deleteStep(String stepId);
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

  @override
  Future<fdom.Step> createStep({
    required String flowId,
    required fdom.StepType type,
    required int order,
    required String content,
    required String mediaRef,
    required int delayMs,
    required int jitterPct,
    required bool aiOnly,
    String? metadataJson,
  }) async {
    final body = <String, dynamic>{
      'type': type.toWire(),
      'order': order,
      'content': content,
      'mediaRef': mediaRef,
      'delayMs': delayMs,
      'jitterPct': jitterPct,
      'aiOnly': aiOnly,
    };
    if (metadataJson != null) {
      // Wire del backend espera `metadata` como objeto JSON literal
      // (json.RawMessage). Decodeamos a Map para que dio re-encodee
      // como object — mandar el string crudo lo encajaría entre comillas.
      body['metadata'] = jsonDecode(metadataJson);
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/flows/$flowId/steps',
        data: body,
      );
      final respBody = res.data;
      if (respBody == null) {
        throw const UnknownFlowsFailure();
      }
      return StepsMapper.stepRespToEntity(StepResp.fromJson(respBody));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapStepMutationDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
  }

  /// Traduce DioException de una mutación de flow (create/update del
  /// flow propio). 422 ⇒ `FlowsInvalidCreateFailure`. En lectura sería
  /// UnknownFlowsFailure — 422 sólo aparece en mutaciones.
  FlowsFailure _mapMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const FlowsInvalidCreateFailure();
    }
    return _mapDioException(e);
  }

  /// Traduce DioException de mutaciones que viven directo sobre el
  /// recurso step (PATCH/DELETE /steps/:id). 422 ⇒ InvalidStepFailure y
  /// 404 ⇒ StepNotFoundFailure (distinto del NotFound del flow padre).
  FlowsFailure _mapStepRouteDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      final status = e.response?.statusCode;
      if (status == 422) return const FlowsInvalidStepFailure();
      if (status == 404) return const FlowsStepNotFoundFailure();
    }
    return _mapDioException(e);
  }

  /// Traduce DioException del POST /flows/:id/steps. 422 ⇒
  /// InvalidStepFailure; 404 sigue siendo el NotFound del flow padre
  /// (que es lo que el path apunta).
  FlowsFailure _mapStepMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const FlowsInvalidStepFailure();
    }
    return _mapDioException(e);
  }

  @override
  Future<void> deleteStep(String stepId) async {
    try {
      await _dio.delete<void>('/steps/$stepId');
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      // 404 = idempotente (el step ya no estaba). No es failure.
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode == 404) {
        return;
      }
      throw _mapStepRouteDioException(e);
    }
  }

  @override
  Future<fdom.Step> patchStep({
    required String stepId,
    String? content,
    int? delayMs,
    int? jitterPct,
    bool? aiOnly,
    int? order,
    String? metadataJson,
  }) async {
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (delayMs != null) body['delayMs'] = delayMs;
    if (jitterPct != null) body['jitterPct'] = jitterPct;
    if (aiOnly != null) body['aiOnly'] = aiOnly;
    if (order != null) body['order'] = order;
    if (metadataJson != null) {
      body['metadata'] = jsonDecode(metadataJson);
    }
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/steps/$stepId',
        data: body,
      );
      final rb = res.data;
      if (rb == null) {
        throw const UnknownFlowsFailure();
      }
      return StepsMapper.stepRespToEntity(StepResp.fromJson(rb));
    } on FlowsFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapStepRouteDioException(e);
    } on FormatException {
      throw const UnknownFlowsFailure();
    } on TypeError {
      throw const UnknownFlowsFailure();
    }
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
