import 'entities/ledger_action.dart';

/// Página de la bitácora: acciones DESC (más recientes primero) y el cursor de
/// la siguiente página hacia atrás (null = última). El cursor avanza por id de
/// fila candidata cruda (el backend descarta fallos), así que una página puede
/// traer menos ítems que el límite.
class AiLedgerPageResult {
  const AiLedgerPageResult({required this.items, required this.nextBefore});

  final List<LedgerAction> items;
  final int? nextBefore;
}

/// Puerto de dominio de la bitácora de acciones con efecto (ADMIN+ en backend).
abstract interface class AiLedgerRepository {
  /// `before` pagina hacia atrás (exclusivo); null = desde el final.
  Future<AiLedgerPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  });
}
