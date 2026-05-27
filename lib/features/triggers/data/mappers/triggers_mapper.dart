import '../../domain/entities/trigger.dart';
import '../dto/trigger_dto.dart';

/// Traduce DTOs del listado de triggers a entidades de dominio.
///
/// El `ArgumentError` del `*.fromWire` se propaga sin envolver — drift
/// del contrato (un valor nuevo en el backend que el cliente no conoce)
/// rompe fail-loud en boot en vez de degradar a un failure reintentable.
///
/// Renombra `type` (wire json key) → `triggerType` (campo de la entity)
/// y `scope` → `TriggerScope`. Ver docstrings en `entities/trigger.dart`.
class TriggersMapper {
  const TriggersMapper._();

  static Trigger triggerRespToEntity(TriggerResp r) {
    final matchType = r.matchType;
    final labelAction = r.labelAction;
    final createdAt = r.createdAt;
    final updatedAt = r.updatedAt;
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('triggerResp sin timestamps no es mappable a entidad');
    }
    return Trigger(
      id: r.id,
      templateId: r.templateId,
      flowId: r.flowId,
      triggerType: TriggerType.fromWire(r.type),
      matchType: matchType == null ? null : MatchType.fromWire(matchType),
      keyword: r.keyword,
      labelId: r.labelId,
      labelAction: labelAction == null ? null : LabelAction.fromWire(labelAction),
      scope: TriggerScope.fromWire(r.scope),
      isActive: r.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Despliega `{items:[...]}` a `List<Trigger>` preservando el orden
  /// del backend.
  static List<Trigger> listToTriggers(ListTriggersResp resp) =>
      resp.items.map(triggerRespToEntity).toList(growable: false);
}
