import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/label_step_metadata.dart';
import '../../domain/entities/step.dart' as fdom;
import '../bloc/flow_steps_bloc.dart';
import 'step_delete.dart';
import 'step_edit_fields.dart';
import 'step_edit_support.dart';
import 'step_failure_copy.dart';
import 'step_media_field.dart';
import 'step_send_options.dart';

export 'step_media_field.dart' show MediaRefPicker;

/// Segundo tiempo del creador de pasos: el sheet de COMPOSICIÓN de un step.
/// El tipo llega decidido — del selector agrupado al crear ([createType]) o
/// del propio step al editar — y el sheet lo muestra como identidad en el
/// header ("Nuevo paso · Imagen"; "Editar paso" + pill del tipo). El campo
/// principal del tipo va primero; retraso/variación/modo viven colapsados
/// en "Opciones de envío" (divulgación progresiva).
///
/// `editing == null` ⇒ modo creación (POST). `editing != null` ⇒ modo
/// edición: fields pre-fillados, submit only-changed (nada cambió ⇒ no-op)
/// y tipo inmutable — mutarlo cambiaría la semántica del paso, así que
/// cambiar de tipo es crear un paso nuevo (el header lo dice en su caption).
/// Rangos espejan al validador del backend (`ataulfo-go/internal/domain/
/// flow/step.go`, ajustar límites primero allí): `delayMs` 1s..5 min
/// (LABEL y END exentos: no envían al wire), `jitterPct` 0..100%.
///
/// El sheet escucha el `FlowStepsBloc`:
/// - Mutating ⇒ submit bloqueado con loading.
/// - Refreshing/Loaded post-submit ⇒ auto-pop del sheet: la mutación ya
///   persistió aunque el refetch posterior falle (flag `_didSubmit` evita
///   cerrar por rebuilds incidentales sin haber disparado nada).
/// - MutationFailed ⇒ sigue montado; copy específico por cubo permite
///   al operador corregir y reintentar.
class StepEditSheet extends StatefulWidget {
  const StepEditSheet({
    super.key,
    this.editing,
    this.createType,
    this.pickMediaRef,
    this.insertOrder,
  }) : assert(
         (editing == null) != (createType == null),
         'crear exige createType; editar toma el tipo del step',
       );

  /// `null` ⇒ modo creación. No-null ⇒ modo edición.
  final fdom.Step? editing;

  /// Tipo elegido en el selector del primer tiempo. Solo aplica al crear;
  /// al editar el tipo viene del propio [editing].
  final fdom.StepType? createType;

  /// Abre el selector de multimedia (galería en modo picker) y resuelve al
  /// `ref` BARE elegido. Aplica tanto al crear como al reemplazar el recurso
  /// de un step en edición. `null` ⇒ el selector queda read-only: no abre
  /// nada, lo que mantiene el sheet testeable aislado.
  final MediaRefPicker? pickMediaRef;

  /// Posición que ocupará el paso nuevo (inserción posicional: el backend
  /// desplaza los siguientes); null = append. Solo aplica al crear.
  final int? insertOrder;

  @override
  State<StepEditSheet> createState() => StepEditSheetState();
}

/// Estado del sheet, público para que el guard de descarte del launcher
/// consulte [shouldGuardDiscard] a través de la GlobalKey del sheet.
class StepEditSheetState extends State<StepEditSheet> {
  static const int _minDelayMs = 1000;
  static const int _maxDelayMs = 5 * 60 * 1000;
  static const int _maxJitterPct = 100;

  late final TextEditingController _contentCtrl;
  late final TextEditingController _mediaCtrl;
  late final TextEditingController _jitterCtrl;
  late final fdom.StepType _type;
  late int _delayMs;

  /// Delay con el que el sheet arrancó, ya curado (el legacy 0 sube al piso
  /// al abrir). Baseline del guard de descarte.
  late int _initialDelayMs;

  /// True si el step en edición traía el delay legacy 0: la curación al piso
  /// ocurrió al abrir y las opciones de envío nacen expandidas con el aviso.
  bool _legacyDelayCured = false;

  late int _jitterPct;

  /// True si el texto de variación excede el rango: error visible en el
  /// campo y submit gateado hasta corregirlo.
  bool _jitterInvalid = false;
  late StepMode _mode;
  bool _didSubmit = false;

  /// Último `metadataJson` emitido por el form CONDITIONAL_TIME. `null` =
  /// form inválido localmente (días vacíos, from>=to, sin destinos).
  String? _ctMetadataJson;

  /// True desde que el operador TOCÓ algo del form CT (señal `onTouched`),
  /// aunque el resultado siga inválido: el guard de descarte distingue así
  /// un form intocado de uno a medias que emite null.
  bool _ctDirty = false;

  /// Config inicial del form CT en edición (ver [hydrateCtInitial]).
  ConditionalTimeMetadata? _ctInitial;

  /// True si la metadata CT original no se pudo leer o sus destinos no
  /// resolvieron: el form pinta el aviso de reemplazo.
  bool _ctRecovered = false;

  /// Último `metadataJson` emitido por el form LABEL. `null` = sin
  /// etiqueta seleccionada (gatea el submit).
  String? _labelMetadataJson;

  /// Metadata hidratada del step original al editar un LABEL; se pasa al form
  /// como `initial`. Parse fallido ⇒ null (el form arranca sin selección).
  LabelStepMetadata? _labelInitial;

  /// Nombre real del archivo elegido (clave `media_filename` del metadata):
  /// `DocumentMessage.FileName` en DOCUMENT y nombre visible del recurso en
  /// la lista para el resto. Viaja junto con el `mediaRef` (cambia sólo al
  /// elegir otro recurso).
  String? _pickedFilename;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _contentCtrl = TextEditingController(text: ed?.content ?? '');
    _mediaCtrl = TextEditingController(text: ed?.mediaRef ?? '');
    _type = ed?.type ?? widget.createType!;
    // Un paso que envía al wire arranca en el piso de 1s; el legacy 0 ya
    // guardado sube al piso al abrir (se cura al guardar y se anuncia en
    // las opciones de envío). LABEL y END no usan pacing: valor tal cual.
    _delayMs = ed?.delayMs ?? _minDelayMs;
    if (!_isLabel && !_isEnd && _delayMs < _minDelayMs) {
      _delayMs = _minDelayMs;
      _legacyDelayCured = ed != null;
    }
    // Baseline del guard: el delay YA curado. La curación del legacy 0 no es
    // trabajo del operador y no debe disparar la confirmación de descarte
    // (el submit sí compara contra el original para persistirla).
    _initialDelayMs = _delayMs;
    _jitterPct = ed?.jitterPct ?? 0;
    _jitterCtrl = TextEditingController(text: '$_jitterPct');
    _mode = StepMode.of(
      aiOnly: ed?.aiOnly ?? false,
      manualOnly: ed?.manualOnly ?? false,
    );
    _contentCtrl.addListener(_onContentChanged);
    _mediaCtrl.addListener(_onContentChanged);
    _jitterCtrl.addListener(_onJitterChanged);

    if (ed != null && ed.type == fdom.StepType.conditionalTime) {
      final hydrated = hydrateCtInitial(
        ed.metadataJson,
        stepsFromState(context.read<FlowStepsBloc>().state),
      );
      _ctInitial = hydrated.initial;
      _ctRecovered = hydrated.recovered;
    }
    if (ed != null && ed.type == fdom.StepType.label) {
      _labelInitial = hydrateLabelInitial(ed.metadataJson);
      // Hidrata el gate ya: el submit arranca habilitado sin esperar al
      // re-emit del form en su primer frame.
      if (_labelInitial != null) _labelMetadataJson = ed.metadataJson;
    }
  }

  void _onContentChanged() => setState(() {});

  void _onJitterChanged() {
    final raw = _jitterCtrl.text.trim();
    setState(() {
      final v = raw.isEmpty ? 0 : int.tryParse(raw);
      // digitsOnly + tope de 3 dígitos hacen improbable el null; el guard
      // conserva el último valor válido por si el formatter cambiara.
      if (v == null) {
        _jitterInvalid = true;
        return;
      }
      _jitterInvalid = v > _maxJitterPct;
      if (!_jitterInvalid) _jitterPct = v;
    });
  }

  @override
  void dispose() {
    _contentCtrl.removeListener(_onContentChanged);
    _mediaCtrl.removeListener(_onContentChanged);
    _jitterCtrl.removeListener(_onJitterChanged);
    _contentCtrl.dispose();
    _mediaCtrl.dispose();
    _jitterCtrl.dispose();
    super.dispose();
  }

  bool get _isConditionalTime => _type == fdom.StepType.conditionalTime;

  bool get _isLabel => _type == fdom.StepType.label;

  bool get _isEnd => _type == fdom.StepType.end;

  Future<void> _confirmDelete() async {
    final ed = widget.editing;
    if (ed == null) return;
    final confirmed = await confirmStepDelete(
      context,
      stepId: ed.id,
      steps: stepsFromState(context.read<FlowStepsBloc>().state),
    );
    if (!confirmed) return;
    if (!mounted) return;
    _didSubmit = true;
    context.read<FlowStepsBloc>().add(FlowStepsDeleteRequested(ed.id));
  }

  /// Submit es válido si el campo "principal" del tipo no está vacío:
  /// para TEXT, `content`; para multimedia, `mediaRef`; para CT/LABEL, el
  /// `metadataJson` emitido por su form. END no lleva campos: siempre
  /// submittable. Una variación fuera de rango gatea a los tipos con pacing.
  bool get _isSubmittable {
    if (!_isLabel && !_isEnd && _jitterInvalid) return false;
    if (_isConditionalTime) return _ctMetadataJson != null;
    if (_isLabel) return _labelMetadataJson != null;
    if (_isEnd) return true;
    if (_type.isMultimediaStep) return _mediaCtrl.text.trim().isNotEmpty;
    return _contentCtrl.text.trim().isNotEmpty;
  }

  /// Foto del estado editable para el diff only-changed (submit y guard).
  StepDraft get _draft => StepDraft(
    content: _contentCtrl.text.trim(),
    mediaRef: _mediaCtrl.text.trim(),
    isConditionalTime: _isConditionalTime,
    isLabel: _isLabel,
    isMultimedia: _type.isMultimediaStep,
    delayMs: _delayMs,
    jitterPct: _jitterPct,
    aiOnly: _mode == StepMode.aiOnly,
    manualOnly: _mode == StepMode.manualOnly,
    ctMetadataJson: _ctMetadataJson,
    ctInitial: _ctInitial,
    labelMetadataJson: _labelMetadataJson,
    labelInitial: _labelInitial,
    mediaMetadataJson: _type.isMultimediaStep
        ? mediaFilenameMetadata(_pickedFilename)
        : null,
  );

  /// True cuando descartar perdería trabajo del operador (la regla vive en
  /// [stepDraftHasUnsavedWork]; la señal de tocado del form CT le permite
  /// proteger también un condicional a medias que aún emite null). Tras un
  /// submit en vuelo o persistido no hay nada que perder (el auto-pop pasa
  /// por maybePop y debe salir directo); un fallo de mutación revierte el
  /// flag.
  bool get shouldGuardDiscard =>
      !_didSubmit &&
      stepDraftHasUnsavedWork(
        _draft,
        widget.editing,
        delayBaseline: _initialDelayMs,
        ctTouched: _ctDirty,
      );

  void _submit() {
    if (!_isSubmittable) return;
    final ed = widget.editing;
    final bloc = context.read<FlowStepsBloc>();
    if (ed == null) {
      _didSubmit = true;
      bloc.add(
        stepAddEvent(
          _type,
          _draft,
          stepsFromState(bloc.state),
          insertAt: widget.insertOrder,
        ),
      );
      return;
    }
    final event = stepUpdateEvent(_draft, ed);
    if (event == null) return; // Nada cambió: no-op sin round-trip.
    _didSubmit = true;
    bloc.add(event);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlowStepsBloc, FlowStepsState>(
      listener: (context, state) {
        // Un fallo de mutación invalida el intento: el cambio NO persistió,
        // el guard debe volver a proteger el trabajo vivo (y un Loaded
        // posterior ajeno a este sheet ya no debe popearlo).
        if (state is FlowStepsMutationFailed) {
          _didSubmit = false;
          return;
        }
        // El pop llega en cuanto la mutación PERSISTIÓ: Refreshing es esa
        // señal (el refetch posterior puede fallar y el cambio ya existe en
        // el backend — un Guardar vivo lo duplicaría). Loaded queda como
        // respaldo por si el bloc entregara el listado sin pasar por
        // Refreshing. El gate `isCurrent` evita el doble pop: el listener
        // sigue montado durante la animación de salida, y sin él un Loaded
        // veloz volvería a popear — comiéndose la página que abrió el sheet.
        if (_didSubmit &&
            (state is FlowStepsRefreshing || state is FlowStepsLoaded) &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).maybePop();
        }
      },
      child: BlocBuilder<FlowStepsBloc, FlowStepsState>(
        builder: (context, state) {
          final isMutating = state is FlowStepsMutating;
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
                  StepEditHeader(
                    type: _type,
                    isEditing: widget.editing != null,
                    enabled: !isMutating,
                    onDelete: _confirmDelete,
                  ),
                  const SizedBox(height: AppTokens.sp4),
                  StepMainField(
                    type: _type,
                    enabled: !isMutating,
                    contentController: _contentCtrl,
                    mediaController: _mediaCtrl,
                    pickMediaRef: widget.pickMediaRef,
                    // Captura el filename real del asset para persistirlo en
                    // el metadata junto al ref.
                    onMediaPicked: (asset) =>
                        setState(() => _pickedFilename = asset.filename),
                    ctInitial: _ctInitial,
                    ctRecovered: _ctRecovered,
                    ctTargets: ctTargetsFromState(state, widget.editing),
                    onCtChanged: (json) =>
                        setState(() => _ctMetadataJson = json),
                    onCtTouched: () => _ctDirty = true,
                    labelInitial: _labelInitial,
                    onLabelChanged: (json) =>
                        setState(() => _labelMetadataJson = json),
                  ),
                  // Pacing y modo son opciones de segundo orden y viven
                  // colapsadas. END no envía nada NI corre condicionado:
                  // no tiene opciones que mostrar.
                  if (!_isEnd) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    StepSendOptions(
                      // LABEL no envía al wire: sin retraso ni variación,
                      // solo el modo de ejecución.
                      showPacing: !_isLabel,
                      legacyDelayCured: _legacyDelayCured,
                      delayMs: _delayMs,
                      minDelayMs: _minDelayMs,
                      maxDelayMs: _maxDelayMs,
                      jitterController: _jitterCtrl,
                      jitterInvalid: _jitterInvalid,
                      mode: _mode,
                      enabled: !isMutating,
                      onDelayChanged: (ms) => setState(() => _delayMs = ms),
                      onModeChanged: (m) => setState(() => _mode = m),
                    ),
                  ],
                  if (failure != null) ...<Widget>[
                    const SizedBox(height: AppTokens.sp4),
                    StepFailureCopy(
                      failure: failure,
                      isConditionalTime: _isConditionalTime,
                    ),
                  ],
                  const SizedBox(height: AppTokens.sp6),
                  StepEditFooter(
                    isMutating: isMutating,
                    canSubmit: _isSubmittable,
                    onSubmit: _submit,
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
