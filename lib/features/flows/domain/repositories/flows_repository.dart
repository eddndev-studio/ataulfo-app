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
}
