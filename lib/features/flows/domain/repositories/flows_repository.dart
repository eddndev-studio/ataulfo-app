import '../entities/flow.dart';
import '../entities/step.dart' as fdom;

/// Puerto de dominio para Flows (S11). Define los verbos que el bloc
/// puede pedir; las implementaciones viven en `data/`.
abstract interface class FlowsRepository {
  /// Listado de flows de una Template. RBAC del backend (CRUD de Flow =
  /// ADMIN+) rechaza con 403 si el rol no alcanza. 404 si la Template
  /// padre no existe en la org. Lista vacía es válida.
  Future<List<Flow>> listFlows(String templateId);

  /// Cabecera de un flow por id. 404 si el flow no existe en la org del
  /// operador (mapea a `FlowsNotFoundFailure`).
  Future<Flow> flowById(String id);

  /// Lista los steps de un flow ordenados por `order` ASC. Lista vacía
  /// es válida (flow sin steps todavía). 404 si el flow padre no existe.
  Future<List<fdom.Step>> listSteps(String flowId);

  /// Crea un Flow asociado a la Template. Body mínimo (sólo `name`);
  /// los gates (`cooldownMs`, `usageLimit`, `excludesFlows`) viajan con
  /// defaults silenciosos y se ajustan después en el Settings tab del
  /// editor. 422 si el nombre rompe la validación → `FlowsInvalidCreateFailure`.
  Future<Flow> createFlow({required String templateId, required String name});

  /// Crea un Step en el flow. El bloc resuelve `order` (último + 1 al
  /// agregar al final) antes de invocar. El backend rechaza con 422 si
  /// el body rompe la validación del dominio del step
  /// → `FlowsInvalidStepFailure`; 404 si el flow padre no existe.
  Future<fdom.Step> createStep({
    required String flowId,
    required fdom.StepType type,
    required int order,
    required String content,
    required String mediaRef,
    required int delayMs,
    required int jitterPct,
    required bool aiOnly,
    bool manualOnly = false,
    String? metadataJson,
  });

  /// Edita un Step (partial update). Campos `null` se omiten — el
  /// backend preserva su valor actual. 422 → `FlowsInvalidStepFailure`;
  /// 404 → `FlowsStepNotFoundFailure` (el step ya no existe — el
  /// listado en pantalla está obsoleto).
  ///
  /// `order` queda para patches puntuales de posición; el reorder
  /// completo por drag&drop usa [reorderSteps] (atómico), no N×PATCH.
  ///
  /// `metadataJson` viaja con el shape literal de `Step.metadata`. Hoy
  /// solo CONDITIONAL_TIME lo necesita (ventanas horarias); otros tipos
  /// no exponen edición de metadata desde la UI.
  ///
  /// `mediaRef` viaja cuando se reemplaza el recurso de un step
  /// multimedia. Es el `ref` BARE canónico, nunca la URL firmada.
  Future<fdom.Step> patchStep({
    required String stepId,
    String? content,
    String? mediaRef,
    int? delayMs,
    int? jitterPct,
    bool? aiOnly,
    bool? manualOnly,
    int? order,
    String? metadataJson,
  });

  /// Elimina un Step. Operación idempotente: si el step no existe, no
  /// falla — el bloc puede asumir que tras éxito el step ya no está en
  /// el servidor. 409 ⇒ `FlowsStepReferencedFailure` (el step es destino
  /// de un condicional; el operador debe redirigirlo antes).
  Future<void> deleteStep(String stepId);

  /// Reordena TODOS los steps del flow en una sola operación atómica:
  /// `ids` es el array completo en el orden destino y el backend renumera
  /// 0..n-1 transaccionalmente. 422 ⇒ `FlowsInvalidReorderFailure`
  /// (permutación inexacta o un condicional quedaría tras sus destinos);
  /// como es atómico, un fallo deja el servidor EXACTAMENTE como estaba.
  Future<void> reorderSteps({
    required String flowId,
    required List<String> ids,
  });

  /// Reemplaza un Flow por id (PUT replace-completo). El editor del
  /// Settings tab debe propagar `name` e `isActive` desde la cabecera
  /// loaded aunque no los edite — omitir un campo reaplica su default
  /// silenciosamente.
  ///
  /// `version` es CAS optimista: 409 ⇒ `FlowsConflictFailure` (version
  /// stale o duplicate name). 422 ⇒ `FlowsInvalidSettingsFailure`
  /// (gates fuera de rango). 404 ⇒ `FlowsNotFoundFailure`.
  Future<Flow> updateFlow({
    required String flowId,
    required int version,
    required String name,
    required bool isActive,
    required bool aiInvocable,
    required int cooldownMs,
    required int usageLimit,
    required List<String> excludesFlows,
  });

  /// Elimina un Flow por id. Idempotente: si el flow no existe, no falla.
  /// El backend borra en cascada los steps y triggers del flow. RBAC del
  /// backend (CRUD de Flow = ADMIN+) rechaza con 403
  /// → `FlowsForbiddenFailure`.
  Future<void> deleteFlow(String flowId);
}
