import '../entities/bot.dart';

/// Puerto de dominio para Bots (S04). Define los verbos que el bloc puede
/// pedir; las implementaciones viven en `data/`.
abstract interface class BotsRepository {
  /// Listado de bots de la org activa. RBAC del backend filtra por rol:
  /// SUPERVISOR+ ven todos; WORKER solo los asignados a su Membership.
  Future<List<Bot>> list();
}
