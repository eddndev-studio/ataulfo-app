import '../../domain/entities/step.dart' as fdom;
import '../dto/step_dto.dart';

/// Traduce DTOs del listado de steps a entidades de dominio.
/// El ArgumentError del `StepType.fromWire` se propaga sin envolver — el
/// drift de contrato (un tipo nuevo en el backend que el cliente no
/// conoce) rompe en boot en vez de degradar a un failure reintentable.
class StepsMapper {
  const StepsMapper._();

  static fdom.Step stepRespToEntity(StepResp resp) => fdom.Step(
    id: resp.id,
    flowId: resp.flowId,
    type: fdom.StepType.fromWire(resp.type),
    order: resp.order,
    content: resp.content,
    mediaRef: resp.mediaRef,
    metadataJson: resp.metadataJson,
    delayMs: resp.delayMs,
    jitterPct: resp.jitterPct,
    aiOnly: resp.aiOnly,
  );

  /// Despliega el wrapper `{items:[...]}` a `List<Step>` preservando el
  /// orden del backend (que ya ordena por `order` ASC en el SQL).
  static List<fdom.Step> listToSteps(ListStepsResp resp) =>
      resp.items.map(stepRespToEntity).toList(growable: false);
}
