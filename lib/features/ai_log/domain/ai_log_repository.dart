import 'entities/ai_log_entry.dart';

/// Página del log de observabilidad: items DESC (más recientes primero) y
/// el cursor de la siguiente página hacia atrás (null = última).
class AiLogPageResult {
  const AiLogPageResult({required this.items, required this.nextBefore});

  final List<AiLogEntry> items;
  final int? nextBefore;
}

/// Puerto de dominio de la vista de observabilidad (ADMIN+ en el backend).
abstract interface class AiLogRepository {
  /// `before` pagina hacia atrás (exclusivo); null = desde el final.
  Future<AiLogPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  });
}
