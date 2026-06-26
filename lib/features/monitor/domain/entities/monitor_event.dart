/// Familia de un evento de actividad del bot runtime, derivada del topic SSE.
enum MonitorEventKind {
  aiTurn,
  aiTool,
  aiCompleted,
  aiFailed,
  flowStarted,
  flowStep,
  flowCompleted,
  flowFailed,
  alert,
  unknown,
  // Sentinel CLIENTE (no viene del wire): el stream se reconectó. Lo emite el
  // reconnectMarker del datasource para que el consumidor pinte la salud del SSE.
  reconnect,
}

/// Un evento de la actividad EN VIVO del bot runtime de un chat, recibido por el
/// SSE `ai-activity` (ADMIN+). Unifica las tres familias del wire (ai.*, flow.*,
/// agent.alert) en un solo tipo: el consumidor (timeline, píldora de estado,
/// alertas) ramifica por `kind`. NO trae el contenido de los mensajes del chat
/// —eso viaja por su propio canal—, solo qué está HACIENDO el bot.
class MonitorEvent {
  const MonitorEvent({
    required this.kind,
    required this.topic,
    required this.at,
    this.chatLid = '',
    this.runId = '',
    this.iteration = 0,
    this.model = '',
    this.toolName = '',
    this.toolError = false,
    this.error = '',
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.flowId = '',
    this.executionId = '',
    this.stepIdx = 0,
    this.category = '',
    this.title = '',
    this.detail = '',
  });

  /// Construye un evento desde el `event:` (topic) y el `data` (json) de un frame
  /// SSE. Tolerante: campos ausentes caen a su default; un topic desconocido es
  /// `unknown` (no crashea ante un topic futuro que el cliente no conoce).
  factory MonitorEvent.fromFrame(String topic, Map<String, dynamic> json) {
    final at =
        DateTime.tryParse(json['at'] as String? ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return MonitorEvent(
      kind: _kindOf(topic),
      topic: topic,
      at: at,
      chatLid: json['chatLid'] as String? ?? '',
      runId: json['runId'] as String? ?? '',
      iteration: _int(json['iteration']),
      model: json['model'] as String? ?? '',
      toolName: json['toolName'] as String? ?? '',
      toolError: json['toolError'] as bool? ?? false,
      error: json['error'] as String? ?? '',
      tokensIn: _int(json['tokensIn']),
      tokensOut: _int(json['tokensOut']),
      flowId: json['flowId'] as String? ?? '',
      executionId: json['executionId'] as String? ?? '',
      stepIdx: _int(json['stepIdx']),
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  final MonitorEventKind kind;

  /// Topic crudo del frame ('ai.tool', 'flow.step', 'agent.alert', …), por si el
  /// consumidor necesita la cadena exacta.
  final String topic;
  final DateTime at;

  /// Chat (LID) al que pertenece el evento. El monitor por-chat ya viene scopeado
  /// y no lo usa; el feed bot-scoped lo necesita para atribuir la señal a su chat.
  final String chatLid;

  // ai.* (toolName/toolError en ai.tool; model+tokens en turn/completed; error
  // en failed).
  final String runId;
  final int iteration;
  final String model;
  final String toolName;
  final bool toolError;
  final String error;
  final int tokensIn;
  final int tokensOut;

  // flow.*
  final String flowId;
  final String executionId;
  final int stepIdx;

  // agent.alert
  final String category;
  final String title;
  final String detail;

  static int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

  static MonitorEventKind _kindOf(String topic) {
    switch (topic) {
      case 'ai.turn':
        return MonitorEventKind.aiTurn;
      case 'ai.tool':
        return MonitorEventKind.aiTool;
      case 'ai.completed':
        return MonitorEventKind.aiCompleted;
      case 'ai.failed':
        return MonitorEventKind.aiFailed;
      case 'flow.started':
        return MonitorEventKind.flowStarted;
      case 'flow.step':
        return MonitorEventKind.flowStep;
      case 'flow.completed':
        return MonitorEventKind.flowCompleted;
      case 'flow.failed':
        return MonitorEventKind.flowFailed;
      case 'agent.alert':
        return MonitorEventKind.alert;
      default:
        return MonitorEventKind.unknown;
    }
  }
}
