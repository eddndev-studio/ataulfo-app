import '../entities/trigger.dart';

/// Puerto de dominio para Triggers (S11). El listado es org-scoped por
/// Template; las mutaciones (create/update/delete) operan sobre el
/// trigger por id (template ya validado al crear).
abstract interface class TriggersRepository {
  /// Listado de triggers de una Template. RBAC del backend
  /// (CRUD de Trigger = ADMIN+ vía template-scope guard) rechaza con 403
  /// si el rol no alcanza. 404 si la Template padre no existe en la org.
  /// Lista vacía es válida (template sin disparadores configurados).
  Future<List<Trigger>> listTriggers(String templateId);

  /// Crea un trigger en la Template. El backend valida que el `flowId`
  /// pertenezca al `templateId` (cross-template guard). 422 si el body
  /// rompe la validación del dominio del trigger.
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

  /// Reemplaza un trigger por id (PUT semantics, no PATCH). El backend
  /// preserva flowId/templateId/createdAt del existente; el cliente NO
  /// puede mover un trigger entre flows. El sheet siempre envía el
  /// documento completo para no reactivar/reescopear silenciosamente.
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

  /// Elimina un trigger. Idempotente: si ya no existe, no falla.
  Future<void> deleteTrigger(String triggerId);
}
