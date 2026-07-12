/// Desenlace persistido de una corrida del bot (objeto top-level `run{}` del
/// drill `?run=`; tabla ai_runs). Se OMITE en corridas viejas o en curso — sin
/// él la vista no inventa el cierre. `status` es "COMPLETED"/"FAILED" y
/// `error` llega CRUDO (err.Error()): la UI SIEMPRE lo traduce con el copy
/// es-MX del core; el crudo solo puede vivir como detalle técnico secundario.
class AiRunOutcome {
  const AiRunOutcome({
    required this.status,
    required this.error,
    required this.iterations,
    required this.tokensIn,
    required this.tokensOut,
    required this.startedAt,
    required this.endedAt,
  });

  final String status;
  final String error;
  final int iterations;
  final int tokensIn;
  final int tokensOut;
  final DateTime startedAt;
  final DateTime endedAt;

  /// La corrida terminó en fallo. Un status futuro desconocido con error no
  /// vacío también cuenta como fallo (mejor un ✗ honesto que un ✓ falso).
  bool get failed => status == 'FAILED' || error.isNotEmpty;

  /// Duración de la corrida (startedAt→endedAt); la UI la pinta SIEMPRE
  /// aproximada («~»). Cero o negativa (relojes) ⇒ null: no se pinta. El zero
  /// time de Go (año 1) es un started_at NULL en ai_runs («solo se conoce el
  /// cierre»): sin arranque real tampoco hay duración que inventar.
  Duration? get duracion {
    if (startedAt.year <= 1) return null;
    final d = endedAt.difference(startedAt);
    return d > Duration.zero ? d : null;
  }
}
