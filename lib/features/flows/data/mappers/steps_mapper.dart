import '../../domain/entities/step.dart' as fdom;
import '../dto/step_dto.dart';

/// Traduce DTOs del listado de steps a entidades de dominio.
/// Un `type` que el cliente no conoce (tipo futuro del backend) degrada a
/// `StepType.unsupported` vía `fromWire` — el flujo carga igual y el paso se
/// renderiza como "actualiza la app", sin perder los demás pasos.
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
