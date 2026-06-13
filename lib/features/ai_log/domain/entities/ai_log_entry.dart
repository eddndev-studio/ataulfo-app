/// Rol de un turno del ConversationLog del motor IA (S12). `unknown`
/// degrada tokens futuros del wire sin romper la carga (misma política que
/// StepType.unsupported).
enum AiLogRole {
  user,
  assistant,
  tool,
  unknown;

  static AiLogRole fromWire(String raw) => switch (raw) {
    'user' => AiLogRole.user,
    'assistant' => AiLogRole.assistant,
    'tool' => AiLogRole.tool,
    _ => AiLogRole.unknown,
  };
}

/// Tool call solicitada por el modelo en un turno assistant.
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  final String id;
  final String name;

  /// Argumentos crudos en JSON (string) — la vista los muestra tal cual,
  /// no los interpreta.
  final String argumentsJson;
}

/// Turno del log de observabilidad del bot: lo que el operador inspecciona
/// para entender qué pensó (reasoning), qué dijo (content) y qué
/// herramientas usó (toolCalls / turno tool con su resultado).
class AiLogEntry {
  const AiLogEntry({
    required this.id,
    required this.runId,
    required this.role,
    required this.content,
    required this.reasoning,
    required this.toolCalls,
    required this.toolCallId,
    required this.toolName,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.createdAt,
  });

  final int id;

  /// Agrupa los turnos de una corrida del motor (user → iteraciones →
  /// cierre). Vacío en filas históricas pre-migración.
  final String runId;
  final AiLogRole role;
  final String content;

  /// Razonamiento que el proveedor expuso (vacío si el modelo no lo emite).
  final String reasoning;
  final List<AiToolCall> toolCalls;
  final String toolCallId;
  final String toolName;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final DateTime createdAt;
}
