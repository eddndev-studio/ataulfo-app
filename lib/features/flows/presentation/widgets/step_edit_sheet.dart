// Archivo > 400 LOC justificado: el sheet es un único modal cohesionado
// que orquesta los 8 step types — TEXT/multimedia comparten controles
// (content + opcional media_url), CONDITIONAL_TIME swap-ea el cuerpo
// por `ConditionalTimeForm` (su widget propio). El sheet sigue siendo
// quien gestiona el ciclo de create/edit, gates de submit, only-changed
// del PATCH y el _FailureCopy contextual. Los helpers privados
// (_TypePicker, _SliderField, _FailureCopy) están acoplados al estado
// de _StepEditSheetState — extraerlos a archivos sueltos movería ruido
// sin mejorar cohesión.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';
import 'conditional_time_form.dart';
import 'step_type_label.dart';

/// Modal sheet de creación/edición de un step TEXT (S11 F5a). Cuenta
/// con tres controles: `content` (TextField multiline), `delayMs` y
/// `jitterPct` (sliders), y `aiOnly` (switch).
///
/// `editing == null` ⇒ modo creación (POST). `editing != null` ⇒ modo
/// edición: fields pre-fillados con los valores actuales, submit
/// dispatcha UpdateRequested only-changed (campos sin cambio no viajan
/// al backend) y si nada cambió el submit es no-op.
///
/// Rangos espejan al validador del backend: `delayMs` 0..5 min,
/// `jitterPct` 0..100%. Cualquier ajuste de límite debe hacerse primero
/// en `agentic-go/internal/domain/flow/step.go` (StepMaxDelayMs /
/// StepMaxJitterPct).
///
/// El sheet escucha el `FlowStepsBloc`:
/// - Mutating ⇒ submit bloqueado con loading.
/// - Loaded post-submit ⇒ auto-pop del sheet (flag `_didSubmit` evita
///   cerrar por rebuilds incidentales sin haber disparado nada).
/// - MutationFailed ⇒ sigue montado; copy específico por cubo permite
///   al operador corregir y reintentar.
class StepEditSheet extends StatefulWidget {
  const StepEditSheet({super.key, this.editing});

  /// `null` ⇒ modo creación. No-null ⇒ modo edición; el sheet se
  /// pre-llena con los valores actuales del step y el submit hace
  /// only-changed contra el original.
  final fdom.Step? editing;

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
];

class _StepEditSheetState extends State<StepEditSheet> {
  static const int _maxDelayMs = 5 * 60 * 1000;
  static const int _maxJitterPct = 100;

  late final TextEditingController _contentCtrl;
  late final TextEditingController _mediaCtrl;
  late fdom.StepType _type;
  late int _delayMs;
  late int _jitterPct;
  late bool _aiOnly;
  bool _didSubmit = false;

  /// Último `metadataJson` emitido por el form CONDITIONAL_TIME.
  /// `null` = el form está inválido localmente (días vacíos, from>=to,
  /// etc.). Solo aplica cuando `_type == conditionalTime`.
  String? _ctMetadataJson;

  /// Metadata hidratada del step original al editar un CONDITIONAL_TIME;
  /// se pasa al form como `initial`. Si el parse falla (legacy/corrupto),
  /// el form arranca con su seed default — el operador verá un warning
  /// implícito al notar que el form no refleja la config guardada.
  ConditionalTimeMetadata? _ctInitial;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _contentCtrl = TextEditingController(text: ed?.content ?? '');
    _mediaCtrl = TextEditingController(text: ed?.mediaRef ?? '');
    _type = ed?.type ?? fdom.StepType.text;
    _delayMs = ed?.delayMs ?? 0;
    _jitterPct = ed?.jitterPct ?? 0;
    _aiOnly = ed?.aiOnly ?? false;
    _contentCtrl.addListener(_onContentChanged);
    _mediaCtrl.addListener(_onContentChanged);

    if (ed != null && ed.type == fdom.StepType.conditionalTime) {
      try {
        _ctInitial = ConditionalTimeMetadata.fromJsonString(ed.metadataJson);
      } on FormatException {
        // metadata corrupto: el form arranca con seed default. El
        // operador puede notar el desajuste y reconfigurar.
        _ctInitial = null;
      }
    }
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
      _type != fdom.StepType.text && _type != fdom.StepType.conditionalTime;

  bool get _isConditionalTime => _type == fdom.StepType.conditionalTime;

  List<int> _availableOrdersFromState(FlowStepsState s) =>
      _availableOrdersFromStateImpl(s, widget.editing?.id);

  Future<void> _confirmDelete() async {
    final ed = widget.editing;
    if (ed == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        key: const Key('step_edit.delete_confirm'),
        title: const Text('Eliminar paso'),
        content: const Text(
          '¿Eliminar este paso? La acción no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('step_edit.delete_confirm.cancel'),
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('step_edit.delete_confirm.ok'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    _didSubmit = true;
    context.read<FlowStepsBloc>().add(FlowStepsDeleteRequested(ed.id));
  }

  /// Submit es válido si el campo "principal" del tipo no está vacío:
  /// para TEXT, `content`; para multimedia, `mediaRef`. El campo
  /// secundario (caption en multimedia) puede quedar vacío.
  /// CONDITIONAL_TIME válida cuando el form local emitió un
  /// `metadataJson` no-null (sin días vacíos, from<to, etc.).
  bool get _isSubmittable {
    if (_isConditionalTime) return _ctMetadataJson != null;
    if (_isMultimedia) return _mediaCtrl.text.trim().isNotEmpty;
    return _contentCtrl.text.trim().isNotEmpty;
  }

  void _submit() {
    if (!_isSubmittable) return;
    final content = _contentCtrl.text.trim();
    final mediaRef = _mediaCtrl.text.trim();
    final ed = widget.editing;
    if (ed == null) {
      _didSubmit = true;
      context.read<FlowStepsBloc>().add(
        FlowStepsAddRequested(
          type: _type,
          mediaRef: _isMultimedia ? mediaRef : '',
          content: _isConditionalTime ? '' : content,
          delayMs: _delayMs,
          jitterPct: _jitterPct,
          aiOnly: _aiOnly,
          metadataJson: _isConditionalTime ? _ctMetadataJson : null,
        ),
      );
      return;
    }

    // Modo edit: only-changed. Diff contra el editing original; si
    // nada cambió, no-op (la UI evita el round-trip).
    final newContent = _isConditionalTime
        ? null // CT no edita content vía sheet — el form maneja todo.
        : content != ed.content
        ? content
        : null;
    final newDelay = _delayMs != ed.delayMs ? _delayMs : null;
    final newJitter = _jitterPct != ed.jitterPct ? _jitterPct : null;
    final newAiOnly = _aiOnly != ed.aiOnly ? _aiOnly : null;

    String? newMetadata;
    if (_isConditionalTime && _ctMetadataJson != null) {
      // Comparación semántica: parseo el JSON original y el actual para
      // evitar falsos positivos por orden de keys distinto del backend.
      try {
        final current = ConditionalTimeMetadata.fromJsonString(
          _ctMetadataJson!,
        );
        if (_ctInitial == null || current != _ctInitial) {
          newMetadata = _ctMetadataJson;
        }
      } on FormatException {
        // El form gates submit con metadataJson != null, así que un
        // parse fail aquí sería bug. Lo dejamos pasar como cambio.
        newMetadata = _ctMetadataJson;
      }
    }

    final isNoOp =
        newContent == null &&
        newDelay == null &&
        newJitter == null &&
        newAiOnly == null &&
        newMetadata == null;
    if (isNoOp) return;

    _didSubmit = true;
    context.read<FlowStepsBloc>().add(
      FlowStepsUpdateRequested(
        stepId: ed.id,
        content: newContent,
        delayMs: newDelay,
        jitterPct: newJitter,
        aiOnly: newAiOnly,
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
          // viewInsets.bottom > 0 sólo con teclado abierto; viewPadding.bottom
          // > 0 siempre en gestos. max() cubre ambos sin doble contar.
          final media = MediaQuery.of(context);
          final bottomInset = math.max(
            media.viewInsets.bottom,
            media.viewPadding.bottom,
          );
          final failure = state is FlowStepsMutationFailed
              ? state.failure
              : null;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
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
                      availableStepOrders: _availableOrdersFromState(state),
                      enabled: !isMutating,
                      onChanged: (json) =>
                          setState(() => _ctMetadataJson = json),
                    ),
                  ] else ...<Widget>[
                    if (_isMultimedia) ...<Widget>[
                      const SizedBox(height: AppTokens.sp4),
                      AppTextField(
                        key: const Key('step_edit.media_url'),
                        label: 'URL o id del recurso',
                        hint: 'https://… o id opaco del archivo subido',
                        controller: _mediaCtrl,
                        // En edit el mediaRef es read-only por la misma
                        // razón que el picker se oculta: cambiar el recurso
                        // multimedia equivale a otro step. Edición de
                        // media (replace de archivo) entra cuando S16
                        // (media-storage) y file pickers aterricen.
                        enabled: !isMutating && widget.editing == null,
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
                  const SizedBox(height: AppTokens.sp4),
                  _SliderField(
                    sliderKey: const Key('step_edit.delay_slider'),
                    label: 'Retraso',
                    valueLabel: _delaySecondsLabel(_delayMs),
                    helper:
                        'Cuánto espera el bot antes de enviar el paso (0–5 min).',
                    value: _delayMs.toDouble(),
                    min: 0,
                    max: _maxDelayMs.toDouble(),
                    divisions: 60,
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
                  const SizedBox(height: AppTokens.sp4),
                  Row(
                    key: const Key('step_edit.ai_only_switch'),
                    children: <Widget>[
                      Switch(
                        value: _aiOnly,
                        onChanged: isMutating
                            ? null
                            : (v) => setState(() => _aiOnly = v),
                      ),
                      const SizedBox(width: AppTokens.sp2),
                      Expanded(
                        child: Text(
                          'Solo IA — el paso lo aplica el agente, no el flujo manual.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTokens.text2,
                          ),
                        ),
                      ),
                    ],
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
    FlowsNotFoundFailure() ||
    FlowsServerFailure() ||
    FlowsInvalidCreateFailure() ||
    FlowsInvalidSettingsFailure() ||
    FlowsConflictFailure() ||
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
              ChoiceChip(
                key: Key('step_edit.type.${t.name}'),
                label: Text(stepTypeLabel(t)),
                selected: selected == t,
                onSelected: enabled ? (_) => onSelected(t) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Extrae los `order` de los steps vigentes del bloc state para los
/// dropdowns `onMatch`/`onElse` del form CT. Excluye el step propio
/// cuando se está editando (auto-referencia es un loop trivial).
/// Loading/Failed iniciales ⇒ lista vacía (los dropdowns muestran
/// "Sin pasos destino disponibles" hasta que aterricen los datos).
List<int> _availableOrdersFromStateImpl(FlowStepsState s, String? editingId) {
  final List<fdom.Step> steps;
  if (s is FlowStepsLoaded) {
    steps = s.steps;
  } else if (s is FlowStepsMutating) {
    steps = s.steps;
  } else if (s is FlowStepsMutationFailed) {
    steps = s.steps;
  } else {
    return const <int>[];
  }
  return steps.where((st) => st.id != editingId).map((st) => st.order).toList();
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
