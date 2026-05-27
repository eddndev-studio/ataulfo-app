import '../entities/trigger.dart';

/// Puerto de dominio para Triggers (S11). Hoy expone sólo el listado
/// org-scoped por Template; F8 lo extenderá con create/update/delete.
abstract interface class TriggersRepository {
  /// Listado de triggers de una Template. RBAC del backend
  /// (CRUD de Trigger = ADMIN+ vía template-scope guard) rechaza con 403
  /// si el rol no alcanza. 404 si la Template padre no existe en la org.
  /// Lista vacía es válida (template sin disparadores configurados).
  Future<List<Trigger>> listTriggers(String templateId);
}
