import '../domain/entities/monitor_event.dart';

/// Fase accionable del turno EN VIVO del bot, derivada del ÚLTIMO evento del
/// feed: los no-terminales (turno/tool/flujo) mantienen un turno activo, un
/// fallo terminal deja `failed`, y todo lo demás (completado OK, alertas,
/// ruido de conexión) es reposo.
enum LiveTurnPhase { idle, active, failed }

/// Origen único del mapeo evento→estado que comparten las superficies de
/// actividad en vivo (la píldora del header y el footer del hilo): si el
/// criterio de "qué mantiene un turno vivo" cambia, cambia solo aquí.
LiveTurnPhase liveTurnPhaseOf(List<MonitorEvent> events) {
  if (events.isEmpty) return LiveTurnPhase.idle;
  switch (events.last.kind) {
    case MonitorEventKind.aiTurn:
    case MonitorEventKind.aiTool:
    case MonitorEventKind.flowStarted:
    case MonitorEventKind.flowStep:
      return LiveTurnPhase.active;
    case MonitorEventKind.aiFailed:
    case MonitorEventKind.flowFailed:
      return LiveTurnPhase.failed;
    case MonitorEventKind.aiCompleted:
    case MonitorEventKind.flowCompleted:
    case MonitorEventKind.alert:
    case MonitorEventKind.unknown:
    case MonitorEventKind.reconnect:
    case MonitorEventKind.connected:
      return LiveTurnPhase.idle;
  }
}

/// Etiqueta de QUÉ hace el bot durante un turno activo (qué tool, o que corre
/// un flujo), o null fuera de uno.
String? liveTurnActivityLabel(List<MonitorEvent> events) {
  if (liveTurnPhaseOf(events) != LiveTurnPhase.active) return null;
  final last = events.last;
  switch (last.kind) {
    case MonitorEventKind.aiTool:
      return last.toolName.isNotEmpty
          ? 'Usando ${last.toolName}…'
          : 'Trabajando…';
    case MonitorEventKind.aiTurn:
      return 'Pensando…';
    // La fase ya acotó a no-terminales: aquí solo quedan los de flujo.
    case MonitorEventKind.flowStarted:
    case MonitorEventKind.flowStep:
    case MonitorEventKind.aiCompleted:
    case MonitorEventKind.aiFailed:
    case MonitorEventKind.flowCompleted:
    case MonitorEventKind.flowFailed:
    case MonitorEventKind.alert:
    case MonitorEventKind.unknown:
    case MonitorEventKind.reconnect:
    case MonitorEventKind.connected:
      return 'Ejecutando un flujo…';
  }
}
