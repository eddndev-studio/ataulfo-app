/// Tipo de un Step dentro de un Flow (S11). Espejo del backend
/// (`ataulfo-go/internal/domain/flow/step.go`):
/// - 6 multimedia/contenido directo: TEXT, IMAGE, VIDEO, DOCUMENT, AUDIO,
///   PTT, STICKER.
/// - 1 ramificación: CONDITIONAL_TIME (evalúa ventanas horarias para
///   bifurcar el flow).
/// - 1 acción: LABEL (aplica/quita una etiqueta interna sobre el chat;
///   su payload vive en metadata `{label_id, action}`).
///
/// Política de wire: tokens **UPPERCASE** canonical. Un token que esta
/// versión de la app no conoce (un tipo futuro del backend, o casing
/// distinto) degrada a [unsupported] en vez de romper la carga del flujo:
/// el paso se renderiza como "actualiza la app" y los demás se preservan.
/// Es la ÚNICA excepción a la política fail-loud, acotada a StepType — un
/// flujo no debe volverse inabrible por un tipo de paso nuevo.
enum StepType {
  text,
  image,
  video,
  document,
  audio,
  ptt,
  sticker,
  conditionalTime,
  label,

  /// Terminador: la ejecución completa al alcanzarlo — la rama que cierra
  /// con END no cae en los pasos siguientes. Es lo que hace expresable un
  /// if/else real con CONDITIONAL_TIME en el motor lineal del backend.
  end,

  /// Centinela para un token de wire desconocido. No se crea desde la UI
  /// (no está en el picker) ni se serializa (toWire lanza): solo aparece al
  /// LEER un flujo con un tipo que esta versión no soporta.
  unsupported;

  static StepType fromWire(String raw) => switch (raw) {
    'TEXT' => StepType.text,
    'IMAGE' => StepType.image,
    'VIDEO' => StepType.video,
    'DOCUMENT' => StepType.document,
    'AUDIO' => StepType.audio,
    'PTT' => StepType.ptt,
    'STICKER' => StepType.sticker,
    'CONDITIONAL_TIME' => StepType.conditionalTime,
    'LABEL' => StepType.label,
    'END' => StepType.end,
    _ => StepType.unsupported,
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
    StepType.label => 'LABEL',
    StepType.end => 'END',
    StepType.unsupported => throw ArgumentError.value(
      this,
      'StepType.toWire',
      'unsupported no tiene token de wire',
    ),
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
    this.manualOnly = false,
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

  /// Inverso de [aiOnly]: el paso solo corre cuando el flujo arranca por
  /// disparador o manualmente — la IA lo salta al conducir vía run_flow.
  /// Ambos flags a la vez son inválidos (422 del backend); el editor lo
  /// previene con un selector excluyente.
  final bool manualOnly;

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
    bool? manualOnly,
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
    manualOnly: manualOnly ?? this.manualOnly,
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
        other.aiOnly == aiOnly &&
        other.manualOnly == manualOnly;
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
    manualOnly,
  );
}
