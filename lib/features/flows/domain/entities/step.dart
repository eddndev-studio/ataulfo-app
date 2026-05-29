/// Tipo de un Step dentro de un Flow (S11). 8 valores espejo del backend
/// (`ataulfo-go/internal/domain/flow/step.go`):
/// - 6 multimedia/contenido directo: TEXT, IMAGE, VIDEO, DOCUMENT, AUDIO,
///   PTT, STICKER.
/// - 1 ramificación: CONDITIONAL_TIME (evalúa ventanas horarias para
///   bifurcar el flow).
///
/// Política de wire: tokens **UPPERCASE** canonical (intencionalmente
/// distinto de `VarType` que usa lowercase; refleja la inconsistencia
/// interna del backend, no se silencia). Cualquier token con casing
/// distinto o fuera del set es drift de contrato y rompe fail-loud.
enum StepType {
  text,
  image,
  video,
  document,
  audio,
  ptt,
  sticker,
  conditionalTime;

  static StepType fromWire(String raw) => switch (raw) {
    'TEXT' => StepType.text,
    'IMAGE' => StepType.image,
    'VIDEO' => StepType.video,
    'DOCUMENT' => StepType.document,
    'AUDIO' => StepType.audio,
    'PTT' => StepType.ptt,
    'STICKER' => StepType.sticker,
    'CONDITIONAL_TIME' => StepType.conditionalTime,
    _ => throw ArgumentError.value(raw, 'StepType.fromWire'),
  };

  String toWire() => switch (this) {
    StepType.text => 'TEXT',
    StepType.image => 'IMAGE',
    StepType.video => 'VIDEO',
    StepType.document => 'DOCUMENT',
    StepType.audio => 'AUDIO',
    StepType.ptt => 'PTT',
    StepType.sticker => 'STICKER',
    StepType.conditionalTime => 'CONDITIONAL_TIME',
  };
}

/// Step — nodo de un Flow. Value object: dos instancias con misma data son
/// iguales.
///
/// `mediaRef`: URL o id opaco del recurso (S16 lo concretará). Hoy es
/// string libre. Vacío cuando el StepType no lo requiere (TEXT,
/// CONDITIONAL_TIME).
///
/// `metadataJson`: blob json crudo (sin parsear). El backend lo trata
/// como jsonb opaco; el cliente lo lee con `jsonDecode` cuando el
/// StepType lo requiere (CONDITIONAL_TIME tiene ventanas horarias,
/// otros tipos pueden ignorarlo). En F2 (read-only) sólo lo
/// preservamos; F7 lo interpretará por tipo.
class Step {
  const Step({
    required this.id,
    required this.flowId,
    required this.type,
    required this.order,
    required this.content,
    required this.mediaRef,
    required this.metadataJson,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
  });

  final String id;
  final String flowId;
  final StepType type;
  final int order;
  final String content;
  final String mediaRef;
  final String metadataJson;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;

  Step copyWith({
    String? id,
    String? flowId,
    StepType? type,
    int? order,
    String? content,
    String? mediaRef,
    String? metadataJson,
    int? delayMs,
    int? jitterPct,
    bool? aiOnly,
  }) => Step(
    id: id ?? this.id,
    flowId: flowId ?? this.flowId,
    type: type ?? this.type,
    order: order ?? this.order,
    content: content ?? this.content,
    mediaRef: mediaRef ?? this.mediaRef,
    metadataJson: metadataJson ?? this.metadataJson,
    delayMs: delayMs ?? this.delayMs,
    jitterPct: jitterPct ?? this.jitterPct,
    aiOnly: aiOnly ?? this.aiOnly,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Step &&
        other.id == id &&
        other.flowId == flowId &&
        other.type == type &&
        other.order == order &&
        other.content == content &&
        other.mediaRef == mediaRef &&
        other.metadataJson == metadataJson &&
        other.delayMs == delayMs &&
        other.jitterPct == jitterPct &&
        other.aiOnly == aiOnly;
  }

  @override
  int get hashCode => Object.hash(
    id,
    flowId,
    type,
    order,
    content,
    mediaRef,
    metadataJson,
    delayMs,
    jitterPct,
    aiOnly,
  );
}
