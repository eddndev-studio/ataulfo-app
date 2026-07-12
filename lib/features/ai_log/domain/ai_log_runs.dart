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

  /// Agregados espejo de [totalTokens] para el header de la corrida: tokens de
  /// entrada al modelo, generados, servidos desde caché y costo en micro-USD.
  int get promptTokens => entries.fold(0, (sum, e) => sum + e.promptTokens);

  int get completionTokens =>
      entries.fold(0, (sum, e) => sum + e.completionTokens);

  int get cachedTokens => entries.fold(0, (sum, e) => sum + e.cachedTokens);

  int get costMicroUsd => entries.fold(0, (sum, e) => sum + e.costMicroUsd);

  DateTime get startedAt => entries.first.createdAt;
}

/// Particiona el stream DESC del wire: corridas REALES (runId no vacío,
/// frontera = cambio de runId) más recientes primero y con turnos
/// cronológicos, y la historia LEGACY (filas pre-migración sin runId) aparte,
/// cronológica y SIN agrupación inventada — la vista la pinta plana como
/// «Actividad previa».
({List<AiLogRun> runs, List<AiLogEntry> legacy}) splitLog(
  List<AiLogEntry> descItems,
) {
  if (descItems.isEmpty) {
    return const (runs: <AiLogRun>[], legacy: <AiLogEntry>[]);
  }
  final asc = descItems.reversed.toList();
  final legacy = <AiLogEntry>[];
  final runs = <AiLogRun>[];
  var current = <AiLogEntry>[];
  var currentRunId = '';

  void flush() {
    if (current.isEmpty) return;
    runs.add(AiLogRun(runId: currentRunId, entries: current));
    current = <AiLogEntry>[];
  }

  for (final e in asc) {
    if (e.runId.isEmpty) {
      legacy.add(e);
      continue;
    }
    if (current.isNotEmpty && e.runId != currentRunId) flush();
    currentRunId = e.runId;
    current.add(e);
  }
  flush();
  return (runs: runs.reversed.toList(), legacy: legacy);
}
