import 'entities/ai_log_entry.dart';

/// Una corrida del motor IA: el turno del usuario, las iteraciones del
/// modelo (con razonamiento y tools) y el cierre. La vista del operador
/// divide el log por corrida — pedido explícito del producto.
class AiLogRun {
  const AiLogRun({required this.runId, required this.entries});

  final String runId;

  /// Turnos en orden cronológico ascendente (como ocurrieron).
  final List<AiLogEntry> entries;

  /// Modelo del último turno assistant con modelo declarado.
  String get model {
    for (final e in entries.reversed) {
      if (e.model.isNotEmpty) return e.model;
    }
    return '';
  }

  int get totalTokens => entries.fold(0, (sum, e) => sum + e.totalTokens);

  DateTime get startedAt => entries.first.createdAt;
}

/// Agrupa el stream DESC del wire en corridas: más recientes primero,
/// turnos cronológicos dentro de cada una. Frontera de corrida: cambio de
/// runId; las filas legacy (runId vacío) abren corrida en cada turno user
/// (la heurística pre-run_id).
List<AiLogRun> groupIntoRuns(List<AiLogEntry> descItems) {
  if (descItems.isEmpty) return const <AiLogRun>[];
  final asc = descItems.reversed.toList();
  final runs = <AiLogRun>[];
  var current = <AiLogEntry>[];
  String currentRunId = asc.first.runId;

  void flush() {
    if (current.isEmpty) return;
    runs.add(AiLogRun(runId: currentRunId, entries: current));
    current = <AiLogEntry>[];
  }

  for (final e in asc) {
    final boundary =
        current.isNotEmpty &&
        (e.runId != currentRunId ||
            (e.runId.isEmpty && e.role == AiLogRole.user));
    if (boundary) {
      flush();
      currentRunId = e.runId;
    }
    if (current.isEmpty) currentRunId = e.runId;
    current.add(e);
  }
  flush();
  return runs.reversed.toList();
}
