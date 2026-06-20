/// Evento de progreso del turno del asistente, recibido por SSE
/// (`platform_agent.{thinking,tool,completed,failed}`). NO trae el contenido
/// del mensaje — el texto del asistente llega por el POST/recarga. Solo
/// alimenta el indicador en vivo ("pensando…/usando {tool}…").
class PaProgressEvent {
  const PaProgressEvent({
    required this.kind,
    required this.conversationId,
    required this.at,
    this.runId = '',
    this.iteration = 0,
    this.model = '',
    this.toolName = '',
    this.toolError = false,
    this.error = '',
  });

  final String kind; // thinking | tool | completed | failed
  final String conversationId;
  final DateTime at;
  final String runId;
  final int iteration;
  final String model;
  final String toolName;
  final bool toolError;
  final String error;

  bool get isThinking => kind == 'thinking';
  bool get isTool => kind == 'tool';
  bool get isCompleted => kind == 'completed';
  bool get isFailed => kind == 'failed';
  bool get isTerminal => isCompleted || isFailed;
}
