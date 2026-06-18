/// Estado de una ejecución de flujo (S11). Taxonomía cerrada del backend;
/// `unknown` es defensa ante un valor no reconocido (no debe tumbar la vista).
enum ExecutionStatus {
  running,
  completed,
  failed,
  unknown;

  static ExecutionStatus fromWire(String s) => switch (s) {
    'RUNNING' => ExecutionStatus.running,
    'COMPLETED' => ExecutionStatus.completed,
    'FAILED' => ExecutionStatus.failed,
    _ => ExecutionStatus.unknown,
  };
}

/// Una corrida del motor de flujos sobre un chat (`GET /sessions/:botId/
/// :chatLid/executions`). El wire NO trae el nombre del flujo (sólo `flowId`):
/// el cliente lo resuelve aparte o muestra el id. `error` viene vacío cuando no
/// hubo fallo; `endedAt` es null mientras sigue corriendo.
class Execution {
  const Execution({
    required this.id,
    required this.botId,
    required this.chatLid,
    required this.flowId,
    required this.templateId,
    required this.status,
    required this.error,
    required this.currentStep,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final String botId;
  final String chatLid;
  final String flowId;
  final String templateId;
  final ExecutionStatus status;
  final String error;
  final int currentStep;
  final DateTime startedAt;
  final DateTime? endedAt;

  @override
  bool operator ==(Object other) =>
      other is Execution &&
      other.id == id &&
      other.status == status &&
      other.error == error;

  @override
  int get hashCode => Object.hash(id, status, error);
}
