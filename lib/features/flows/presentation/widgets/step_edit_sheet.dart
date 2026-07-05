// Archivo > 400 LOC justificado: el sheet es un único modal cohesionado
// que orquesta los 8 step types — TEXT/multimedia comparten controles
// (content + opcional media_url), CONDITIONAL_TIME swap-ea el cuerpo
// por `ConditionalTimeForm` (su widget propio). El sheet sigue siendo
// quien gestiona el ciclo de create/edit, gates de submit, only-changed
// del PATCH y el _FailureCopy contextual. Los helpers privados
// (_TypePicker, _SliderField, _FailureCopy) están acoplados al estado
// de _StepEditSheetState — extraerlos a archivos sueltos movería ruido
// sin mejorar cohesión.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_confirm_dialog.dart';
import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../media/domain/entities/media_asset.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';
import '../media_step_name.dart';
import 'conditional_time_form.dart';
import 'label_step_form.dart';
import 'step_type_label.dart';

/// Abre un selector de multimedia filtrado por [family] (image|video|audio|
/// document, o null = sin filtro) y devuelve el [MediaAsset] elegido, o `null`
/// si el usuario cancela. El caller persiste el ref BARE canónico
/// (`tenant/<org>/media/<id>[.<ext>]`) — JAMÁS la `previewUrl` firmada efímera —
/// y el filename del asset (para documentos). El `BuildContext` se pasa para que
/// el selector pueda navegar (p. ej. `context.push('/media/pick?type=<family>')`).
typedef MediaRefPicker =
    Future<MediaAsset?> Function(BuildContext context, String? family);

/// Modal sheet de creación/edición de un step TEXT (S11 F5a). Cuenta
/// con tres controles: `content` (TextField multiline), `delayMs` y
/// `jitterPct` (sliders), y el modo de ejecución (chips excluyentes
/// Siempre / Solo IA / Solo disparadores que mapean a `aiOnly`/`manualOnly`).
///
/// `editing == null` ⇒ modo creación (POST). `editing != null` ⇒ modo
/// edición: fields pre-fillados con los valores actuales, submit
/// dispatcha UpdateRequested only-changed (campos sin cambio no viajan
/// al backend) y si nada cambió el submit es no-op.
///
/// Rangos espejan al validador del backend: `delayMs` 1s..5 min (LABEL exento:
/// no envía al wire), `jitterPct` 0..100%. Cualquier ajuste de límite debe
/// hacerse primero en `ataulfo-go/internal/domain/flow/step.go`
/// (StepMinDelayMs / StepMaxDelayMs / StepMaxJitterPct).
///
/// El sheet escucha el `FlowStepsBloc`:
/// - Mutating ⇒ submit bloqueado con loading.
/// - Loaded post-submit ⇒ auto-pop del sheet (flag `_didSubmit` evita
///   cerrar por rebuilds incidentales sin haber disparado nada).
/// - MutationFailed ⇒ sigue montado; copy específico por cubo permite
///   al operador corregir y reintentar.
class StepEditSheet extends StatefulWidget {
  const StepEditSheet({super.key, this.editing, this.pickMediaRef});

  /// `null` ⇒ modo creación. No-null ⇒ modo edición; el sheet se
  /// pre-llena con los valores actuales del step y el submit hace
  /// only-changed contra el original.
  final fdom.Step? editing;

  /// Abre el selector de multimedia (galería en modo picker) y resuelve al
  /// `ref` BARE elegido. Aplica tanto al crear como al reemplazar el recurso
  /// de un step en edición. `null` ⇒ el selector queda read-only: no abre
  /// nada, lo que mantiene el sheet testeable aislado.
  final MediaRefPicker? pickMediaRef;

  @override
  State<StepEditSheet> createState() => _StepEditSheetState();
}

/// Tipos que el picker del sheet expone — el set completo de StepType.
/// TEXT y multimedia comparten controles (content + opcional media_url);
/// CONDITIONAL_TIME swap-ea el cuerpo del sheet por un form propio con
/// ventanas horarias y ramificación.
const List<fdom.StepType> _pickableTypes = <fdom.StepType>[
  fdom.StepType.text,
  fdom.StepType.image,
  fdom.StepType.video,
  fdom.StepType.document,
  fdom.StepType.audio,
  fdom.StepType.ptt,
  fdom.StepType.sticker,
  fdom.StepType.conditionalTime,
  fdom.StepType.label,
  fdom.StepType.end,
];

class _StepEditSheetState extends State<StepEditSheet> {
  static const int _minDelayMs = 1000;
  static const int _maxDelayMs = 5 * 60 * 1000;
  static const int _maxJitterPct = 100;

  late final TextEditingController _contentCtrl;
  late final TextEditingController _mediaCtrl;
  late fdom.StepType _type;
  late int _delayMs;
  late int _jitterPct;
  late _StepMode _mode;
  bool _didSubmit = false;

  /// Último `metadataJson` emitido por el form CONDITIONAL_TIME.
  /// `null` = el form está inválido localmente (días vacíos, from>=to,
  /// etc.). Solo aplica cuando `_type == conditionalTime`.
  String? _ctMetadataJson;

  /// Metadata hidratada del step original al editar un CONDITIONAL_TIME;
  /// se pasa al form como `initial`. Metadata legacy posicional se SANA
  /// resolviendo orders→ids contra los steps vigentes del bloc.
  ConditionalTimeMetadata? _ctInitial;

  /// True cuando la metadata original no se pudo leer o sus destinos no
  /// resolvieron: el form pinta un aviso EXPLÍCITO de que guardar
  /// reemplaza la configuración anterior (antes el reemplazo era mudo).
  bool _ctRecovered = false;

  /// Último `metadataJson` emitido por el form LABEL. `null` = sin etiqueta
  /// seleccionada (gatea el submit). Solo aplica cuando `_type == label`.
  String? _labelMetadataJson;

  /// Metadata hidratada del step original al editar un LABEL; se pasa al form
  /// como `initial`. Parse fallido ⇒ null (el form arranca sin selección).
  LabelStepMetadata? _labelInitial;

  /// Nombre real del archivo elegido (clave `media_filename` del metadata). Se
  /// guarda para CUALQUIER paso multimedia: el backend lo usa como
  /// `DocumentMessage.FileName` en DOCUMENT, y el cliente lo muestra como nombre
  /// del recurso en la lista de pasos para los demás tipos. Se setea al elegir
  /// un asset y viaja junto con el `mediaRef` (cambia sólo al elegir otro
  /// recurso).
  String? _pickedFilename;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _contentCtrl = TextEditingController(text: ed?.content ?? '');
    _mediaCtrl = TextEditingController(text: ed?.mediaRef ?? '');
    _type = ed?.type ?? fdom.StepType.text;
    // Un paso que envía al wire arranca en el piso de 1s; un paso legacy con
    // delay 0 ya guardado sube al piso al abrir el editor (se cura al guardar,
    // y mantiene el valor dentro del rango del slider). LABEL no usa pacing
    // (slider oculto), conserva su valor.
    _delayMs = ed?.delayMs ?? _minDelayMs;
    if (_type != fdom.StepType.label && _delayMs < _minDelayMs) {
      _delayMs = _minDelayMs;
    }
    _jitterPct = ed?.jitterPct ?? 0;
    _mode = _StepMode.of(
      aiOnly: ed?.aiOnly ?? false,
      manualOnly: ed?.manualOnly ?? false,
    );
    _contentCtrl.addListener(_onContentChanged);
    _mediaCtrl.addListener(_onContentChanged);

    if (ed != null && ed.type == fdom.StepType.conditionalTime) {
      try {
        var md = ConditionalTimeMetadata.fromJsonString(ed.metadataJson);
        if (!md.hasStepIdRefs) {
          // Fila legacy posicional (no migrada): sanar resolviendo los
          // orders contra los steps vigentes. Si algún destino no
          // resuelve, el horario se conserva y los destinos quedan sin
          // selección con el aviso de reemplazo.
          final steps = _stepsFromState(context.read<FlowStepsBloc>().state);
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
            _ctRecovered = true;
            md = ConditionalTimeMetadata(tz: md.tz, windows: md.windows);
          }
        }
        _ctInitial = md;
      } on FormatException {
        // Metadata corrupta: el form arranca con seed default y el aviso
        // explícito de que guardar reemplaza lo anterior.
        _ctInitial = null;
        _ctRecovered = true;
      }
    }
    if (ed != null && ed.type == fdom.StepType.label) {
      try {
        _labelInitial = LabelStepMetadata.fromJsonString(ed.metadataJson);
        // El form re-emitirá esto en su primer frame, pero hidratamos el gate
        // ya para que el submit arranque habilitado sin esperar al callback.
        _labelMetadataJson = ed.metadataJson;
      } on FormatException {
        // metadata corrupto: el form arranca sin selección. El operador
        // re-elige etiqueta y acción.
        _labelInitial = null;
      }
    }
  }

  /// Familia de content-type por la que filtrar el picker, derivada del tipo del
  /// paso. STICKER usa el contenedor de imagen; AUDIO/PTT comparten audio.
  /// DOCUMENT no filtra (null): un paso documento envía cualquier archivo como
  /// adjunto descargable, así que el picker ofrece toda la galería (p. ej. para
  /// mandar un audio como documento). TEXT/CONDITIONAL_TIME no llevan media ⇒ null.
  static String? _mediaFamilyFor(fdom.StepType type) => switch (type) {
    fdom.StepType.image || fdom.StepType.sticker => 'image',
    fdom.StepType.video => 'video',
    fdom.StepType.audio || fdom.StepType.ptt => 'audio',
    fdom.StepType.document ||
    fdom.StepType.text ||
    fdom.StepType.conditionalTime ||
    fdom.StepType.label ||
    fdom.StepType.end ||
    fdom.StepType.unsupported => null,
  };

  /// Metadata JSON con el nombre del recurso de un paso multimedia:
  /// `{"media_filename": "..."}`. No multimedia, o sin filename conocido ⇒ null
  /// (no se escribe metadata). El nombre identifica al mismo asset que el
  /// `mediaRef`, así que viaja junto con él.
  String? _mediaMetadataJson() {
    final name = _pickedFilename?.trim();
    if (!_isMultimedia || name == null || name.isEmpty) {
      return null;
    }
    return jsonEncode(<String, dynamic>{'media_filename': name});
  }

  void _onContentChanged() => setState(() {});

  @override
  void dispose() {
    _contentCtrl.removeListener(_onContentChanged);
    _mediaCtrl.removeListener(_onContentChanged);
    _contentCtrl.dispose();
    _mediaCtrl.dispose();
    super.dispose();
  }

  bool get _isMultimedia =>
      _type != fdom.StepType.text &&
      _type != fdom.StepType.conditionalTime &&
      _type != fdom.StepType.label &&
      _type != fdom.StepType.end &&
      _type != fdom.StepType.unsupported;

  bool get _isConditionalTime => _type == fdom.StepType.conditionalTime;

  bool get _isLabel => _type == fdom.StepType.label;

  bool get _isEnd => _type == fdom.StepType.end;

  List<CtTargetOption> _ctTargetsFromState(FlowStepsState s) =>
      _ctTargetsFromStateImpl(s, widget.editing);

  Future<void> _confirmDelete() async {
    final ed = widget.editing;
    if (ed == null) return;
    // Aviso anticipado: si el paso es destino de un condicional, el
    // backend rechazará el borrado (409). Mejor decirlo ANTES del intento.
    final referenced = _referencedByConditional(
      ed.id,
      _stepsFromState(context.read<FlowStepsBloc>().state),
    );
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Eliminar paso',
      message: referenced
          ? 'Este paso es destino de un condicional del flujo. Para '
                'eliminarlo, primero cambia ese destino en el condicional.'
          : '¿Eliminar este paso? La acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      confirmKey: const Key('step_edit.delete_confirm.ok'),
      cancelKey: const Key('step_edit.delete_confirm.cancel'),
    );
    if (!confirmed) return;
    if (!mounted) return;
    _didSubmit = true;
    context.read<FlowStepsBloc>().add(FlowStepsDeleteRequested(ed.id));
  }

  /// Submit es válido si el campo "principal" del tipo no está vacío:
  /// para TEXT, `content`; para multimedia, `mediaRef`. El campo
  /// secundario (caption en multimedia) puede quedar vacío.
  /// CONDITIONAL_TIME válida cuando el form local emitió un
  /// `metadataJson` no-null (destinos elegidos, días, from<to). END no
  /// lleva campos: siempre submittable.
  bool get _isSubmittable {
    if (_isConditionalTime) return _ctMetadataJson != null;
    if (_isLabel) return _labelMetadataJson != null;
    if (_isEnd) return true;
    if (_isMultimedia) return _mediaCtrl.text.trim().isNotEmpty;
    return _contentCtrl.text.trim().isNotEmpty;
  }

  /// Posición de inserción para un CT nuevo: justo antes de su destino
  /// más temprano (el backend desplaza los steps en/tras esa posición,
  /// así que ambos destinos quedan DESPUÉS del condicional — la regla
  /// forward-only se cumple por construcción). Sin destinos resolubles
  /// cae a append (el backend rechazará con 422 explicativo — fail-loud,
  /// no silencio).
  int? _ctInsertOrder(FlowStepsState s) {
    final json = _ctMetadataJson;
    if (json == null) return null;
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(json);
    } on FormatException {
      return null;
    }
    if (!md.hasStepIdRefs) return null;
    final steps = _stepsFromState(s);
    int? min;
    for (final st in steps) {
      if (st.id != md.onMatchStepId && st.id != md.onElseStepId) continue;
      if (min == null || st.order < min) min = st.order;
    }
    return min;
  }

  void _submit() {
    if (!_isSubmittable) return;
    final content = _contentCtrl.text.trim();
    final mediaRef = _mediaCtrl.text.trim();
    final ed = widget.editing;
    if (ed == null) {
      final bloc = context.read<FlowStepsBloc>();
      _didSubmit = true;
      bloc.add(
        FlowStepsAddRequested(
          type: _type,
          mediaRef: _isMultimedia ? mediaRef : '',
          content: (_isConditionalTime || _isLabel || _isEnd) ? '' : content,
          // LABEL y END no envían al wire: el piso de 1s no aplica.
          delayMs: (_isLabel || _isEnd) ? 0 : _delayMs,
          jitterPct: _isEnd ? 0 : _jitterPct,
          aiOnly: _mode == _StepMode.aiOnly,
          manualOnly: _mode == _StepMode.manualOnly,
          metadataJson: _isConditionalTime
              ? _ctMetadataJson
              : _isLabel
              ? _labelMetadataJson
              : _mediaMetadataJson(),
          // El condicional se INSERTA antes de su destino más temprano;
          // los demás tipos conservan el append clásico.
          order: _isConditionalTime ? _ctInsertOrder(bloc.state) : null,
        ),
      );
      return;
    }

    // Modo edit: only-changed. Diff contra el editing original; si
    // nada cambió, no-op (la UI evita el round-trip).
    final newContent = (_isConditionalTime || _isLabel)
        ? null // CT/LABEL no editan content vía sheet — su form maneja todo.
        : content != ed.content
        ? content
        : null;
    // Solo multimedia reemplaza recurso: el nuevo ref viaja si cambió y no
    // quedó vacío. TEXT/CONDITIONAL_TIME nunca mandan mediaRef.
    final newMediaRef =
        _isMultimedia && mediaRef.isNotEmpty && mediaRef != ed.mediaRef
        ? mediaRef
        : null;
    final newDelay = _delayMs != ed.delayMs ? _delayMs : null;
    final newJitter = _jitterPct != ed.jitterPct ? _jitterPct : null;
    final modeAiOnly = _mode == _StepMode.aiOnly;
    final modeManualOnly = _mode == _StepMode.manualOnly;
    final newAiOnly = modeAiOnly != ed.aiOnly ? modeAiOnly : null;
    final newManualOnly = modeManualOnly != ed.manualOnly
        ? modeManualOnly
        : null;

    String? newMetadata;
    if (_isConditionalTime && _ctMetadataJson != null) {
      // Comparación semántica por shape CANÓNICO (tz + ventanas + ids):
      // el listado del backend sintetiza on_*_order junto a los ids y el
      // form re-emite id-form puro — comparar con el == del entity (que
      // incluye los orders) marcaría cambio en CADA edición sin cambios
      // y dispararía un PATCH espurio.
      try {
        final current = ConditionalTimeMetadata.fromJsonString(
          _ctMetadataJson!,
        );
        final initial = _ctInitial;
        if (initial == null || !_ctCanonicallyEqual(current, initial)) {
          newMetadata = _ctMetadataJson;
        }
      } on FormatException {
        // El form gates submit con metadataJson != null, así que un
        // parse fail aquí sería bug. Lo dejamos pasar como cambio.
        newMetadata = _ctMetadataJson;
      }
    } else if (_isLabel && _labelMetadataJson != null) {
      // Comparación semántica contra el original (label_id + action), para no
      // mandar un PATCH si nada cambió.
      try {
        final current = LabelStepMetadata.fromJsonString(_labelMetadataJson!);
        if (_labelInitial == null || current != _labelInitial) {
          newMetadata = _labelMetadataJson;
        }
      } on FormatException {
        newMetadata = _labelMetadataJson;
      }
    } else if (_isMultimedia) {
      // El media_filename acompaña al ref: cambia sólo cuando se elige otro
      // recurso (otro ref). Si el ref no cambió, el nombre tampoco ⇒ no se manda
      // metadata y el backend conserva el existente.
      if (newMediaRef != null) {
        newMetadata = _mediaMetadataJson();
      }
    }

    final isNoOp =
        newContent == null &&
        newMediaRef == null &&
        newDelay == null &&
        newJitter == null &&
        newAiOnly == null &&
        newManualOnly == null &&
        newMetadata == null;
    if (isNoOp) return;

    _didSubmit = true;
    context.read<FlowStepsBloc>().add(
      FlowStepsUpdateRequested(
        stepId: ed.id,
        content: newContent,
        mediaRef: newMediaRef,
        delayMs: newDelay,
        jitterPct: newJitter,
        aiOnly: newAiOnly,
        manualOnly: newManualOnly,
        metadataJson: newMetadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocListener<FlowStepsBloc, FlowStepsState>(
      listener: (context, state) {
        if (_didSubmit && state is FlowStepsLoaded) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<FlowStepsBloc, FlowStepsState>(
        builder: (context, state) {
          final isMutating = state is FlowStepsMutating;
          final canSubmit = _isSubmittable;
          final failure = state is FlowStepsMutationFailed
              ? state.failure
              : null;
          return Padding(
            padding: EdgeInsets.only(bottom: context.sheetBottomInset),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.sp6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.editing == null ? 'Nuevo paso' : 'Editar paso',
                          style: textTheme.titleLarge,
                        ),
                      ),
                      if (widget.editing != null)
                        IconButton(
                          key: const Key('step_edit.delete'),
                          tooltip: 'Eliminar paso',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppTokens.danger,
                          ),
                          onPressed: isMutating ? null : _confirmDelete,
                        ),
                    ],
                  ),
                  // El picker solo aparece al crear. En edit el tipo es
                  // inmutable por decisión de UX: mutar el tipo de un
                  // step ya creado cambia la semántica del paso (TEXT con
                  // mediaRef no tiene sentido, multimedia sin mediaRef
                  // rompe la validación del backend). Cambiar el tipo
                  // implica borrar y recrear — flujo distinto que el
                  // editor no expone aún.
                  if (widget.editing == null) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    _TypePicker(
                      selected: _type,
                      enabled: !isMutating,
                      onSelected: (t) => setState(() => _type = t),
                    ),
                  ],
                  if (_isConditionalTime) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    ConditionalTimeForm(
                      key: const Key('step_edit.ct_form'),
                      initial: _ctInitial,
                      targets: _ctTargetsFromState(state),
                      enabled: !isMutating,
                      showRecoveredWarning: _ctRecovered,
                      onChanged: (json) =>
                          setState(() => _ctMetadataJson = json),
                    ),
                  ] else if (_isEnd) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    Text(
                      'El flujo termina al llegar a este paso. Úsalo para '
                      'cerrar la rama de un condicional: sin él, la rama '
                      'continúa con los pasos siguientes.',
                      key: const Key('step_edit.end_helper'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ] else if (_isLabel) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    LabelStepForm(
                      initial: _labelInitial,
                      enabled: !isMutating,
                      onChanged: (json) =>
                          setState(() => _labelMetadataJson = json),
                    ),
                  ] else ...<Widget>[
                    if (_isMultimedia) ...<Widget>[
                      const SizedBox(height: AppTokens.sp4),
                      _MediaField(
                        controller: _mediaCtrl,
                        // Tanto al crear como al editar el selector es
                        // interactivo: en edición el operador puede reemplazar
                        // el recurso (el ref BARE resultante viaja en el PATCH).
                        // Sin `pickMediaRef` el selector no abre nada — el
                        // sheet sigue usable aislado.
                        pickMediaRef: widget.pickMediaRef,
                        // La galería-picker se abre filtrada por la familia del
                        // tipo del paso (alineación tipo↔asset).
                        family: _mediaFamilyFor(_type),
                        // Al elegir, capturamos el filename real del asset para
                        // persistirlo en el metadata del documento.
                        onPicked: (asset) =>
                            setState(() => _pickedFilename = asset.filename),
                        enabled: !isMutating,
                      ),
                    ],
                    const SizedBox(height: AppTokens.sp4),
                    AppTextField(
                      key: const Key('step_edit.content'),
                      label: _isMultimedia ? 'Caption (opcional)' : 'Mensaje',
                      hint: _isMultimedia
                          ? 'Texto que acompaña al recurso (opcional)'
                          : 'Lo que el bot enviará al usuario',
                      controller: _contentCtrl,
                      enabled: !isMutating,
                      autofocus: !_isMultimedia,
                      maxLines: 4,
                    ),
                  ],
                  // delay/jitter son pacing del envío al wire: LABEL no envía
                  // nada (side-effect invisible) y END termina la ejecución,
                  // así que sus sliders no aplican y se ocultan.
                  if (!_isLabel && !_isEnd) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    _SliderField(
                      sliderKey: const Key('step_edit.delay_slider'),
                      label: 'Retraso',
                      valueLabel: _delaySecondsLabel(_delayMs),
                      helper:
                          'Cuánto espera el bot antes de enviar el paso (1 s a 5 min).',
                      value: _delayMs.toDouble(),
                      min: _minDelayMs.toDouble(),
                      max: _maxDelayMs.toDouble(),
                      // Granularidad de 1 s en todo el rango [1 s, 5 min].
                      divisions: (_maxDelayMs - _minDelayMs) ~/ 1000,
                      enabled: !isMutating,
                      onChanged: (v) => setState(() => _delayMs = v.round()),
                    ),
                    const SizedBox(height: AppTokens.sp4),
                    _SliderField(
                      sliderKey: const Key('step_edit.jitter_slider'),
                      label: 'Variación',
                      valueLabel: '$_jitterPct%',
                      helper:
                          'Aleatoriedad sobre el retraso para sonar humano (±%).',
                      value: _jitterPct.toDouble(),
                      min: 0,
                      max: _maxJitterPct.toDouble(),
                      divisions: _maxJitterPct,
                      enabled: !isMutating,
                      onChanged: (v) => setState(() => _jitterPct = v.round()),
                    ),
                  ],
                  const SizedBox(height: AppTokens.sp4),
                  Wrap(
                    spacing: AppTokens.sp2,
                    runSpacing: AppTokens.sp2,
                    children: <Widget>[
                      for (final mode in _StepMode.values)
                        AppChoiceChip(
                          key: Key(mode.chipKey),
                          label: mode.label,
                          selected: _mode == mode,
                          onSelected: isMutating
                              ? null
                              : (_) => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.sp2),
                  Text(
                    _mode.helper,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTokens.text2,
                    ),
                  ),
                  if (failure != null) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    _FailureCopy(
                      failure: failure,
                      isConditionalTime: _isConditionalTime,
                    ),
                  ],
                  const SizedBox(height: AppTokens.sp6),
                  AppButton.filled(
                    key: const Key('step_edit.submit'),
                    label: 'Guardar',
                    onPressed: canSubmit ? _submit : null,
                    loading: isMutating,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Modo de ejecución del paso. Mapea 1:1 a los flags excluyentes del wire
/// (`aiOnly`/`manualOnly`); el selector garantiza a-lo-más-uno-true, así el
/// 422 de exclusión del backend es inalcanzable desde este editor.
enum _StepMode {
  always(
    chipKey: 'step_edit.mode.always',
    label: 'Siempre',
    helper:
        'El paso corre tanto por disparador como cuando la IA conduce el flujo.',
  ),
  aiOnly(
    chipKey: 'step_edit.mode.ai',
    label: 'Solo IA',
    helper: 'El paso lo ejecuta solo el agente de IA cuando conduce el flujo.',
  ),
  manualOnly(
    chipKey: 'step_edit.mode.manual',
    label: 'Solo disparadores',
    helper:
        'El paso corre solo cuando el flujo arranca por disparador o manualmente; la IA lo salta.',
  );

  const _StepMode({
    required this.chipKey,
    required this.label,
    required this.helper,
  });

  final String chipKey;
  final String label;
  final String helper;

  static _StepMode of({required bool aiOnly, required bool manualOnly}) {
    if (aiOnly) return _StepMode.aiOnly;
    if (manualOnly) return _StepMode.manualOnly;
    return _StepMode.always;
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.sliderKey,
    required this.label,
    required this.valueLabel,
    required this.helper,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueLabel;
  final String helper;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
            ),
            const Spacer(),
            Text(valueLabel, style: textTheme.bodyMedium),
          ],
        ),
        Slider(
          key: sliderKey,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
        Text(
          helper,
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      ],
    );
  }
}

class _FailureCopy extends StatelessWidget {
  const _FailureCopy({required this.failure, required this.isConditionalTime});

  final FlowsFailure failure;
  final bool isConditionalTime;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure, isConditionalTime);
    return Text(
      copy,
      key: Key(key),
      style: const TextStyle(color: AppTokens.danger),
    );
  }

  static (String key, String copy) _resolve(
    FlowsFailure f,
    bool isCT,
  ) => switch (f) {
    FlowsInvalidStepFailure() =>
      isCT
          ? (
              'step_edit.error.invalid_step.conditional',
              'Revisa horario o destinos del condicional.',
            )
          : (
              'step_edit.error.invalid_step',
              'Revisa los campos del paso: el mensaje no puede estar vacío.',
            ),
    FlowsForbiddenFailure() => (
      'step_edit.error.forbidden',
      'Tu rol no permite editar pasos. Pide acceso a un admin.',
    ),
    FlowsNetworkFailure() || FlowsTimeoutFailure() => (
      'step_edit.error.network',
      'Sin conexión con el servidor. Revisa tu red y reintenta.',
    ),
    FlowsStepNotFoundFailure() => (
      'step_edit.error.step_not_found',
      'Este paso ya no existe. Cierra y refresca la lista.',
    ),
    FlowsStepReferencedFailure() => (
      'step_edit.error.step_referenced',
      'Este paso es destino de un condicional. Cambia ese destino antes '
          'de eliminarlo.',
    ),
    FlowsNotFoundFailure() ||
    FlowsServerFailure() ||
    FlowsInvalidCreateFailure() ||
    FlowsInvalidSettingsFailure() ||
    FlowsConflictFailure() ||
    FlowsInvalidReorderFailure() ||
    UnknownFlowsFailure() => (
      'step_edit.error.generic',
      'No pudimos guardar el paso. Inténtalo de nuevo.',
    ),
  };
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final fdom.StepType selected;
  final bool enabled;
  final ValueChanged<fdom.StepType> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Tipo',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        Wrap(
          spacing: AppTokens.sp2,
          runSpacing: AppTokens.sp2,
          children: <Widget>[
            for (final t in _pickableTypes)
              AppChoiceChip(
                key: Key('step_edit.type.${t.name}'),
                label: stepTypeLabel(t),
                selected: selected == t,
                onSelected: enabled ? (_) => onSelected(t) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Selector del recurso multimedia del step. El [controller] es la fuente de
/// verdad del `ref` BARE: el gate de submit y el evento de creación leen
/// `controller.text`, no este widget.
///
/// Sin ref: muestra un control tappable (`step_edit.media_picker`) que abre
/// la galería en modo picker vía [pickMediaRef] y guarda el ref devuelto. Con
/// ref: muestra un chip (`step_edit.media_selected`) con una cola corta del
/// ref más un botón "Cambiar" (`step_edit.media_change`) que reabre el picker.
///
/// El widget es read-only cuando [pickMediaRef] es `null` o cuando [enabled]
/// es false (mutación en vuelo): el control no abre nada y el chip no expone
/// "Cambiar". NUNCA renderiza la `previewUrl` ni una miniatura — sólo el ref
/// BARE en texto —, así no arrastra la URL firmada efímera a la UI.
class _MediaField extends StatelessWidget {
  const _MediaField({
    required this.controller,
    required this.pickMediaRef,
    required this.family,
    required this.onPicked,
    required this.enabled,
  });

  final TextEditingController controller;
  final MediaRefPicker? pickMediaRef;

  /// Familia de content-type para filtrar la galería-picker (image|video|
  /// audio|document) según el tipo del paso; null ⇒ sin filtro.
  final String? family;

  /// Notifica al padre el asset elegido (para capturar su filename). El ref
  /// BARE va por el [controller]; este callback lleva el resto del asset.
  final ValueChanged<MediaAsset> onPicked;

  final bool enabled;

  bool get _interactive => enabled && pickMediaRef != null;

  Future<void> _pick(BuildContext context) async {
    final picker = pickMediaRef;
    if (picker == null) return;
    final asset = await picker(context, family);
    if (asset == null) return;
    final ref = asset.ref.trim();
    if (ref.isEmpty) return;
    // Setear el texto dispara el listener del controller (en el padre), que
    // hace setState y re-renderiza con el chip seleccionado. El filename viaja
    // por onPicked. NUNCA se persiste asset.previewUrl (firmada efímera).
    controller.text = ref;
    // Asignar `.text` deja la selección en offset -1 (inválida); enfocar el
    // campo seleccionaría todo. Colapsamos el caret al final para poder editar.
    controller.selection = TextSelection.collapsed(offset: ref.length);
    onPicked(asset);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ref = controller.text.trim();
    if (ref.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Recurso',
            style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
          ),
          const SizedBox(height: AppTokens.sp2),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.tonal(
              key: const Key('step_edit.media_picker'),
              label: 'Seleccionar multimedia',
              icon: Icons.perm_media_outlined,
              onPressed: _interactive ? () => _pick(context) : null,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recurso',
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp2),
        Container(
          key: const Key('step_edit.media_selected'),
          padding: const EdgeInsets.all(AppTokens.sp3),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppTokens.primary,
              ),
              const SizedBox(width: AppTokens.sp2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Recurso seleccionado', style: textTheme.bodyMedium),
                    const SizedBox(height: AppTokens.sp1),
                    Text(
                      // Cola corta del ref (display-only). La fuente de verdad
                      // sigue siendo el ref BARE completo en el controller.
                      shortMediaRef(ref),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTokens.text2,
                      ),
                    ),
                  ],
                ),
              ),
              if (_interactive)
                AppButton.text(
                  key: const Key('step_edit.media_change'),
                  label: 'Cambiar',
                  onPressed: () => _pick(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Steps vigentes del bloc state (Loading/Failed iniciales ⇒ vacío).
List<fdom.Step> _stepsFromState(FlowStepsState s) {
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
List<CtTargetOption> _ctTargetsFromStateImpl(
  FlowStepsState s,
  fdom.Step? editing,
) {
  final steps = _stepsFromState(s);
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
bool _ctCanonicallyEqual(ConditionalTimeMetadata a, ConditionalTimeMetadata b) {
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
bool _referencedByConditional(String id, List<fdom.Step> steps) {
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

/// Convierte ms a un label legible. <60s muestra "Xs"; 60s+ muestra
/// "Xm Ys".
String _delaySecondsLabel(int ms) {
  if (ms == 0) return '0s';
  final secs = ms ~/ 1000;
  if (secs < 60) return '${secs}s';
  final minutes = secs ~/ 60;
  final remainder = secs % 60;
  return remainder == 0 ? '${minutes}m' : '${minutes}m ${remainder}s';
}
