import '../entities/flow.dart';

/// Puerto de dominio para Flows (S11). Define los verbos que el bloc
/// puede pedir; las implementaciones viven en `data/`.
abstract interface class FlowsRepository {
  /// Listado de flows de una Template. RBAC del backend (CRUD de Flow =
  /// ADMIN+) rechaza con 403 si el rol no alcanza. 404 si la Template
  /// padre no existe en la org. Lista vacía es válida.
  Future<List<Flow>> listFlows(String templateId);
}
