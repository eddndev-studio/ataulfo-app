import 'dart:convert';

import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import '../bloc/flow_steps_bloc.dart';
import 'conditional_time_form.dart';
import 'step_type_label.dart';

/// Familias de comportamiento de un [fdom.StepType] dentro del editor: qué
/// campos monta el sheet y qué reglas de pacing aplican. Centralizado para
/// que el sheet, sus secciones y los builders de eventos decidan igual.
extension StepTypeFamily on fdom.StepType {
  /// Tipos que envían un recurso multimedia (llevan `mediaRef` + caption).
  bool get isMultimediaStep =>
      this != fdom.StepType.text &&
      this != fdom.StepType.conditionalTime &&
      this != fdom.StepType.label &&
      this != fdom.StepType.end &&
      this != fdom.StepType.unsupported;
}

/// Resultado del diff only-changed de una edición: cada campo no-null
/// difiere del step original y viaja en el PATCH. Todos null ⇒ no hay nada
/// que guardar (submit no-op) ni que perder (descarte sin confirmación).
class StepPatch {
  const StepPatch({
    this.content,
    this.mediaRef,
    this.delayMs,
    this.jitterPct,
    this.aiOnly,
    this.manualOnly,
    this.metadataJson,
  });

  final String? content;
  final String? mediaRef;
  final int? delayMs;
  final int? jitterPct;
  final bool? aiOnly;
  final bool? manualOnly;
  final String? metadataJson;

  bool get isEmpty =>
      content == null &&
      mediaRef == null &&
      delayMs == null &&
      jitterPct == null &&
      aiOnly == null &&
      manualOnly == null &&
      metadataJson == null;
}

/// Foto inmutable de lo editado en el sheet de composición, para calcular el
/// diff only-changed fuera del widget. El sheet la arma desde sus controllers
/// y flags; [buildStepEditPatch] la compara contra el step original.
class StepDraft {
  const StepDraft({
    required this.content,
    required this.mediaRef,
    required this.isConditionalTime,
    required this.isLabel,
    required this.isMultimedia,
    required this.delayMs,
    required this.jitterPct,
    required this.aiOnly,
    required this.manualOnly,
    required this.ctMetadataJson,
    required this.ctInitial,
    required this.labelMetadataJson,
    required this.labelInitial,
    required this.mediaMetadataJson,
  });

  final String content;
  final String mediaRef;
  final bool isConditionalTime;
  final bool isLabel;
  final bool isMultimedia;
  final int delayMs;
  final int jitterPct;
  final bool aiOnly;
  final bool manualOnly;
  final String? ctMetadataJson;
  final ConditionalTimeMetadata? ctInitial;
  final String? labelMetadataJson;
  final LabelStepMetadata? labelInitial;
  final String? mediaMetadataJson;
}

/// Diff only-changed del draft contra el step en edición: cada campo no-null
/// del [StepPatch] cambió respecto del original. [delayBaseline] separa a los
/// dos consumidores: el submit compara contra el delay original del step (así
/// la curación del legacy 0 viaja en el PATCH) y el guard de descarte contra
/// el delay ya curado con que el sheet abrió (la curación no es trabajo del
/// operador y no debe pedir confirmación).
StepPatch buildStepEditPatch(
  StepDraft d,
  fdom.Step ed, {
  required int delayBaseline,
}) {
  final newContent = (d.isConditionalTime || d.isLabel)
      ? null // CT/LABEL no editan content vía sheet — su form maneja todo.
      : d.content != ed.content
      ? d.content
      : null;
  // Solo multimedia reemplaza recurso: el nuevo ref viaja si cambió y no
  // quedó vacío. TEXT/CONDITIONAL_TIME nunca mandan mediaRef.
  final newMediaRef =
      d.isMultimedia && d.mediaRef.isNotEmpty && d.mediaRef != ed.mediaRef
      ? d.mediaRef
      : null;
  final newDelay = d.delayMs != delayBaseline ? d.delayMs : null;
  final newJitter = d.jitterPct != ed.jitterPct ? d.jitterPct : null;
  final newAiOnly = d.aiOnly != ed.aiOnly ? d.aiOnly : null;
  final newManualOnly = d.manualOnly != ed.manualOnly ? d.manualOnly : null;

  String? newMetadata;
  if (d.isConditionalTime && d.ctMetadataJson != null) {
    // Comparación semántica por shape CANÓNICO (tz + ventanas + ids):
    // el listado del backend sintetiza on_*_order junto a los ids y el
    // form re-emite id-form puro — comparar con el == del entity (que
    // incluye los orders) marcaría cambio en CADA edición sin cambios
    // y dispararía un PATCH espurio.
    try {
      final current = ConditionalTimeMetadata.fromJsonString(d.ctMetadataJson!);
      final initial = d.ctInitial;
      if (initial == null || !ctCanonicallyEqual(current, initial)) {
        newMetadata = d.ctMetadataJson;
      }
    } on FormatException {
      // El form gates submit con metadataJson != null, así que un
      // parse fail aquí sería bug. Lo dejamos pasar como cambio.
      newMetadata = d.ctMetadataJson;
    }
  } else if (d.isLabel && d.labelMetadataJson != null) {
    // Comparación semántica contra el original (label_id + action), para no
    // mandar un PATCH si nada cambió.
    try {
      final current = LabelStepMetadata.fromJsonString(d.labelMetadataJson!);
      if (d.labelInitial == null || current != d.labelInitial) {
        newMetadata = d.labelMetadataJson;
      }
    } on FormatException {
      newMetadata = d.labelMetadataJson;
    }
  } else if (d.isMultimedia) {
    // El media_filename acompaña al ref: cambia sólo cuando se elige otro
    // recurso (otro ref). Si el ref no cambió, el nombre tampoco ⇒ no se
    // manda metadata y el backend conserva el existente.
    if (newMediaRef != null) {
      newMetadata = d.mediaMetadataJson;
    }
  }

  return StepPatch(
    content: newContent,
    mediaRef: newMediaRef,
    delayMs: newDelay,
    jitterPct: newJitter,
    aiOnly: newAiOnly,
    manualOnly: newManualOnly,
    metadataJson: newMetadata,
  );
}

/// Evento de ALTA construido del draft: zeroing por tipo (LABEL y END no
/// envían al wire, así que el piso de 1 s no aplica), metadata por familia
/// y la inserción posicional del condicional — se INSERTA antes de su
/// destino más temprano; los demás tipos conservan el append clásico.
FlowStepsAddRequested stepAddEvent(
  fdom.StepType type,
  StepDraft d,
  List<fdom.Step> steps,
) {
  final isCt = type == fdom.StepType.conditionalTime;
  final isLabel = type == fdom.StepType.label;
  final isEnd = type == fdom.StepType.end;
  return FlowStepsAddRequested(
    type: type,
    mediaRef: d.isMultimedia ? d.mediaRef : '',
    content: (isCt || isLabel || isEnd) ? '' : d.content,
    delayMs: (isLabel || isEnd) ? 0 : d.delayMs,
    jitterPct: isEnd ? 0 : d.jitterPct,
    aiOnly: d.aiOnly,
    manualOnly: d.manualOnly,
    metadataJson: isCt
        ? d.ctMetadataJson
        : isLabel
        ? d.labelMetadataJson
        : d.mediaMetadataJson,
    order: isCt ? ctInsertOrder(d.ctMetadataJson, steps) : null,
  );
}

/// Evento de EDICIÓN only-changed contra el step original, o `null` si nada
/// cambió (submit no-op: la UI evita el round-trip). El baseline del delay
/// es el ORIGINAL del step: si traía un legacy 0 curado al abrir, el PATCH
/// lo persiste al piso aunque el operador no lo haya tocado.
FlowStepsUpdateRequested? stepUpdateEvent(StepDraft d, fdom.Step ed) {
  final patch = buildStepEditPatch(d, ed, delayBaseline: ed.delayMs);
  if (patch.isEmpty) return null;
  return FlowStepsUpdateRequested(
    stepId: ed.id,
    content: patch.content,
    mediaRef: patch.mediaRef,
    delayMs: patch.delayMs,
    jitterPct: patch.jitterPct,
    aiOnly: patch.aiOnly,
    manualOnly: patch.manualOnly,
    metadataJson: patch.metadataJson,
  );
}

/// Resultado de hidratar la metadata CT de un step en edición: la config
/// inicial para el form y si hubo RECUPERACIÓN (metadata ilegible o destinos
/// irresolubles) — el form pinta entonces el aviso explícito de que guardar
/// reemplaza la configuración anterior (antes el reemplazo era mudo).
typedef CtHydration = ({ConditionalTimeMetadata? initial, bool recovered});

/// Hidrata la metadata de un CONDITIONAL_TIME en edición. Una fila legacy
/// posicional (no migrada) se SANA resolviendo orders→ids contra los steps
/// vigentes; si algún destino no resuelve, el horario se conserva y los
/// destinos quedan sin selección, marcando recuperación.
CtHydration hydrateCtInitial(String metadataJson, List<fdom.Step> steps) {
  try {
    var md = ConditionalTimeMetadata.fromJsonString(metadataJson);
    if (!md.hasStepIdRefs) {
      final byOrder = <int, String>{for (final s in steps) s.order: s.id};
      final m = byOrder[md.onMatchOrder];
      final e = byOrder[md.onElseOrder];
      if (m != null && e != null) {
        md = ConditionalTimeMetadata(
          tz: md.tz,
          windows: md.windows,
          onMatchStepId: m,
          onElseStepId: e,
        );
      } else {
        return (
          initial: ConditionalTimeMetadata(tz: md.tz, windows: md.windows),
          recovered: true,
        );
      }
    }
    return (initial: md, recovered: false);
  } on FormatException {
    // Metadata corrupta: el form arranca con seed default y el aviso
    // explícito de reemplazo.
    return (initial: null, recovered: true);
  }
}

/// Hidrata la metadata de un LABEL en edición; parse fallido ⇒ null (el
/// form arranca sin selección y el operador re-elige etiqueta y acción).
LabelStepMetadata? hydrateLabelInitial(String metadataJson) {
  try {
    return LabelStepMetadata.fromJsonString(metadataJson);
  } on FormatException {
    return null;
  }
}

/// Metadata JSON con el nombre del recurso de un paso multimedia:
/// `{"media_filename": "..."}`. Sin filename conocido ⇒ null (no se escribe
/// metadata). El nombre identifica al mismo asset que el `mediaRef`, así que
/// viaja junto con él.
String? mediaFilenameMetadata(String? filename) {
  final name = filename?.trim();
  if (name == null || name.isEmpty) return null;
  return jsonEncode(<String, dynamic>{'media_filename': name});
}

/// Steps vigentes del bloc state (Loading/Failed iniciales ⇒ vacío).
List<fdom.Step> stepsFromState(FlowStepsState s) {
  if (s is FlowStepsLoaded) return s.steps;
  if (s is FlowStepsMutating) return s.steps;
  if (s is FlowStepsMutationFailed) return s.steps;
  return const <fdom.Step>[];
}

/// Candidatos a destino para los dropdowns del form CT, con etiqueta
/// legible. Al CREAR, todos los steps son candidatos (el condicional se
/// inserta antes de su destino más temprano, así que el forward-only se
/// cumple por construcción). Al EDITAR no hay re-inserción: solo los
/// steps estrictamente posteriores al propio CT son válidos (el backend
/// rechaza lo demás con 422).
List<CtTargetOption> ctTargetsFromState(FlowStepsState s, fdom.Step? editing) {
  final steps = stepsFromState(s);
  return <CtTargetOption>[
    for (final st in steps)
      if (st.id != editing?.id && (editing == null || st.order > editing.order))
        CtTargetOption(id: st.id, order: st.order, label: _ctTargetLabel(st)),
  ];
}

/// Etiqueta corta de un step candidato a destino: el contenido para TEXT,
/// el tipo humanizado para el resto (el operador reconoce el paso sin
/// salir del sheet).
String _ctTargetLabel(fdom.Step st) {
  if (st.type == fdom.StepType.text && st.content.isNotEmpty) {
    return st.content;
  }
  return stepTypeLabel(st.type);
}

/// Igualdad por shape CANÓNICO de un CT: tz + ventanas + destinos por id.
/// Ignora los orders legacy/sintetizados a propósito — son display, no
/// configuración (el == del entity los incluye y daría falsos cambios).
bool ctCanonicallyEqual(ConditionalTimeMetadata a, ConditionalTimeMetadata b) {
  if (a.tz != b.tz ||
      a.onMatchStepId != b.onMatchStepId ||
      a.onElseStepId != b.onElseStepId ||
      a.windows.length != b.windows.length) {
    return false;
  }
  for (var i = 0; i < a.windows.length; i++) {
    if (a.windows[i] != b.windows[i]) return false;
  }
  return true;
}

/// Reporta si `id` es destino de algún condicional del flow (refs por id).
/// Metadata ilegible o legacy se omite — el backend es la red final (409).
bool referencedByConditional(String id, List<fdom.Step> steps) {
  for (final st in steps) {
    if (st.type != fdom.StepType.conditionalTime) continue;
    try {
      final md = ConditionalTimeMetadata.fromJsonString(st.metadataJson);
      if (md.onMatchStepId == id || md.onElseStepId == id) return true;
    } on FormatException {
      continue;
    }
  }
  return false;
}

/// Posición de inserción para un CT nuevo: justo antes de su destino
/// más temprano (el backend desplaza los steps en/tras esa posición,
/// así que ambos destinos quedan DESPUÉS del condicional — la regla
/// forward-only se cumple por construcción). Sin destinos resolubles
/// cae a append (el backend rechazará con 422 explicativo — fail-loud,
/// no silencio).
int? ctInsertOrder(String? metadataJson, List<fdom.Step> steps) {
  if (metadataJson == null) return null;
  final ConditionalTimeMetadata md;
  try {
    md = ConditionalTimeMetadata.fromJsonString(metadataJson);
  } on FormatException {
    return null;
  }
  if (!md.hasStepIdRefs) return null;
  int? min;
  for (final st in steps) {
    if (st.id != md.onMatchStepId && st.id != md.onElseStepId) continue;
    if (min == null || st.order < min) min = st.order;
  }
  return min;
}
