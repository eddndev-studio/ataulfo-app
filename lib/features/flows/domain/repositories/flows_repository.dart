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
  });
}
