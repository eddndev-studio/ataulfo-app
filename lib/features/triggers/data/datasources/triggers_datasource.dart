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

  /// `POST /templates/:templateId/triggers` body completo del trigger.
  /// Devuelve 201 con el trigger creado (incluye id asignado por el
  /// backend, timestamps).
  ///
  /// Discriminación TEXT vs LABEL: en modo TEXT el cliente NO manda
  /// `labelId`/`labelAction`; en modo LABEL no manda `keyword`/
  /// `matchType`. El backend (`triggerOptionsFrom`) selecciona la
  /// `TriggerOption` por `triggerType`; lo del modo contrario se ignoraría
  /// igual, pero ser explícito acota el contrato del cliente.
  ///
  /// 422 → [TriggersInvalidFailure] (campo inválido o regex que no
  /// compila / dispara el guard anti-ReDoS). 403 → [TriggersForbiddenFailure]
  /// (rol no alcanza, CRUD = ADMIN+). 404 → [TriggersNotFoundFailure]
  /// (la Template padre no existe).
  Future<Trigger> createTrigger({
    required String templateId,
    required String flowId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  });

  /// `PUT /triggers/:triggerId` con documento completo (no PATCH). El
  /// backend reemplaza el trigger reusando ID/OrgID/TemplateID/FlowID/
  /// CreatedAt del existente — el `flowId` NO se cambia desde el cliente
  /// (decisión backend; mover un trigger entre flows requiere borrar y
  /// recrear). Tampoco viaja en el body: enviarlo sería ruido — el
  /// `triggerOptionsFrom` del backend no aplica `WithFlow`.
  ///
  /// PUT replace-completo: omitir `isActive`/`scope` reaplicaría sus
  /// defaults (`true`/`BOTH`) — el cliente siempre los envía aunque no
  /// cambien para no reactivar un trigger pausado al editar otra cosa.
  ///
  /// 422 → [TriggersInvalidFailure]. 404 → [TriggersNotFoundFailure]
  /// (el trigger fue borrado por otro operador entre el listado y el
  /// PUT; el sheet debe forzar refresh).
  Future<Trigger> updateTrigger({
    required String triggerId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  });

  /// `DELETE /triggers/:triggerId` idempotente. 204 sin body si existía,
  /// 404 si ya no estaba — ambos se tratan como éxito desde el cliente
  /// (el operador pidió "que no esté"; el contrato cumple). 403 sigue
  /// emitiendo [TriggersForbiddenFailure] (RBAC).
  Future<void> deleteTrigger(String triggerId);
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

  @override
  Future<Trigger> createTrigger({
    required String templateId,
    required String flowId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'flowId': flowId,
      'type': triggerType.toWire(),
      'scope': scope.toWire(),
      'isActive': isActive,
    };
    if (triggerType == TriggerType.text) {
      body['matchType'] = matchType!.toWire();
      body['keyword'] = keyword;
    } else {
      body['labelId'] = labelId;
      body['labelAction'] = labelAction!.toWire();
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/templates/$templateId/triggers',
        data: body,
      );
      final respBody = res.data;
      if (respBody == null) {
        throw const UnknownTriggersFailure();
      }
      return TriggersMapper.triggerRespToEntity(TriggerResp.fromJson(respBody));
    } on TriggersFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapMutationDioException(e);
    } on FormatException {
      throw const UnknownTriggersFailure();
    } on TypeError {
      throw const UnknownTriggersFailure();
    }
  }

  @override
  Future<Trigger> updateTrigger({
    required String triggerId,
    required TriggerType triggerType,
    required MatchType? matchType,
    required String keyword,
    required String labelId,
    required LabelAction? labelAction,
    required TriggerScope scope,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'type': triggerType.toWire(),
      'scope': scope.toWire(),
      'isActive': isActive,
    };
    if (triggerType == TriggerType.text) {
      body['matchType'] = matchType!.toWire();
      body['keyword'] = keyword;
    } else {
      body['labelId'] = labelId;
      body['labelAction'] = labelAction!.toWire();
    }
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/triggers/$triggerId',
        data: body,
      );
      final respBody = res.data;
      if (respBody == null) {
        throw const UnknownTriggersFailure();
      }
      return TriggersMapper.triggerRespToEntity(TriggerResp.fromJson(respBody));
    } on TriggersFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapMutationDioException(e);
    } on FormatException {
      throw const UnknownTriggersFailure();
    } on TypeError {
      throw const UnknownTriggersFailure();
    }
  }

  @override
  Future<void> deleteTrigger(String triggerId) async {
    try {
      await _dio.delete<void>('/triggers/$triggerId');
    } on TriggersFailure {
      rethrow;
    } on DioException catch (e) {
      // 404 = idempotente (el trigger ya no estaba). El operador pidió
      // "que no esté"; el contrato cumple.
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode == 404) {
        return;
      }
      throw _mapMutationDioException(e);
    }
  }

  /// Traduce DioException de mutaciones de trigger. 422 ⇒ Invalid;
  /// el resto delega en `_mapDioException`. 404 sigue mapeando a
  /// [TriggersNotFoundFailure] (sin discriminar template-vs-trigger;
  /// el contexto del call site permite al bloc/sheet interpretar).
  TriggersFailure _mapMutationDioException(DioException e) {
    if (e.type == DioExceptionType.badResponse &&
        e.response?.statusCode == 422) {
      return const TriggersInvalidFailure();
    }
    return _mapDioException(e);
  }

  /// Traduce DioException a la jerarquía sellada de TriggersFailure.
  /// Espejo fiel del `_mapDioException` de FlowsDatasource (sin mapeos
  /// de 422 — esos viven en `_mapMutationDioException`).
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
