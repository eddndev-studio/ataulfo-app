import '../../domain/entities/flow.dart';
import '../dto/flow_dto.dart';

/// Traduce DTOs del listado de flows a entidades de dominio.
class FlowsMapper {
  const FlowsMapper._();

  static Flow flowRespToEntity(FlowResp resp) => Flow(
    id: resp.id,
    templateId: resp.templateId,
    name: resp.name,
    isActive: resp.isActive,
    version: resp.version,
    cooldownMs: resp.cooldownMs,
    usageLimit: resp.usageLimit,
    excludesFlows: resp.excludesFlows,
  );

  /// Despliega el wrapper `{items:[...]}` a `List<Flow>` preservando el
  /// orden del backend (sin sorting client-side — el backend ya decide
  /// la presentación).
  static List<Flow> listToFlows(ListFlowsResp resp) =>
      resp.items.map(flowRespToEntity).toList(growable: false);
}
