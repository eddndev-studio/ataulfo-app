import 'entities/ai_log_entry.dart';
import 'entities/ai_run_outcome.dart';

/// Página del log de observabilidad: items DESC (más recientes primero) y
/// el cursor de la siguiente página hacia atrás (null = última).
class AiLogPageResult {
  const AiLogPageResult({required this.items, required this.nextBefore});

  final List<AiLogEntry> items;
  final int? nextBefore;
}

/// Resultado del drill `?run=`: los items de ESA corrida (ASC) y su desenlace
/// persistido, `null` si el wire lo omitió (corrida vieja o en curso — la
/// vista no inventa el cierre).
class AiLogRunResult {
  const AiLogRunResult({required this.items, required this.run});

  final List<AiLogEntry> items;
  final AiRunOutcome? run;
}

/// Puerto de dominio de la vista de observabilidad (ADMIN+ en el backend).
abstract interface class AiLogRepository {
  /// `before` pagina hacia atrás (exclusivo); null = desde el final.
  Future<AiLogPageResult> page({
    required String botId,
    required String chatLid,
    int? before,
  });

  /// Resuelve la corrida de IA que produjo un OUTBOUND (su wamid) → runId, o
  /// `null` si el mensaje no salió de la IA.
  Future<String?> runForMessage({
    required String botId,
    required String chatLid,
    required String externalId,
  });

  /// Entries de UNA corrida (ASC) por su runId + el desenlace `run{}` si el
  /// wire lo trae.
  Future<AiLogRunResult> byRun({
    required String botId,
    required String chatLid,
    required String runId,
  });
}
