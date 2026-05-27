import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/step.dart' as fdom;
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';

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

class _StepEditSheetState extends State<StepEditSheet> {
  static const int _maxDelayMs = 5 * 60 * 1000;
  static const int _maxJitterPct = 100;

  late final TextEditingController _contentCtrl;
  late int _delayMs;
  late int _jitterPct;
  late bool _aiOnly;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    final ed = widget.editing;
    _contentCtrl = TextEditingController(text: ed?.content ?? '');
    _delayMs = ed?.delayMs ?? 0;
    _jitterPct = ed?.jitterPct ?? 0;
    _aiOnly = ed?.aiOnly ?? false;
    _contentCtrl.addListener(_onContentChanged);
  }

  void _onContentChanged() => setState(() {});

  @override
  void dispose() {
    _contentCtrl.removeListener(_onContentChanged);
    _contentCtrl.dispose();
    super.dispose();
  }

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

  void _submit() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    final ed = widget.editing;
    if (ed == null) {
      _didSubmit = true;
      context.read<FlowStepsBloc>().add(
        FlowStepsAddRequested(
          content: content,
          delayMs: _delayMs,
          jitterPct: _jitterPct,
          aiOnly: _aiOnly,
        ),
      );
      return;
    }

    // Modo edit: only-changed. Diff contra el editing original; si
    // nada cambió, no-op (la UI evita el round-trip).
    final newContent = content != ed.content ? content : null;
    final newDelay = _delayMs != ed.delayMs ? _delayMs : null;
    final newJitter = _jitterPct != ed.jitterPct ? _jitterPct : null;
    final newAiOnly = _aiOnly != ed.aiOnly ? _aiOnly : null;
    final isNoOp =
        newContent == null &&
        newDelay == null &&
        newJitter == null &&
        newAiOnly == null;
    if (isNoOp) return;

    _didSubmit = true;
    context.read<FlowStepsBloc>().add(
      FlowStepsUpdateRequested(
        stepId: ed.id,
        content: newContent,
        delayMs: newDelay,
        jitterPct: newJitter,
        aiOnly: newAiOnly,
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
          final content = _contentCtrl.text.trim();
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
                  const SizedBox(height: AppTokens.sp4),
                  AppTextField(
                    key: const Key('step_edit.content'),
                    label: 'Mensaje',
                    hint: 'Lo que el bot enviará al usuario',
                    controller: _contentCtrl,
                    enabled: !isMutating,
                    autofocus: true,
                    maxLines: 4,
                  ),
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
                    _FailureCopy(failure: failure),
                  ],
                  const SizedBox(height: AppTokens.sp6),
                  AppButton.filled(
                    key: const Key('step_edit.submit'),
                    label: 'Guardar',
                    onPressed: content.isEmpty ? null : _submit,
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
  const _FailureCopy({required this.failure});

  final FlowsFailure failure;

  @override
  Widget build(BuildContext context) {
    final (key, copy) = _resolve(failure);
    return Text(
      copy,
      key: Key(key),
      style: const TextStyle(color: AppTokens.danger),
    );
  }

  static (String key, String copy) _resolve(FlowsFailure f) => switch (f) {
    FlowsInvalidStepFailure() => (
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
    UnknownFlowsFailure() => (
      'step_edit.error.generic',
      'No pudimos guardar el paso. Inténtalo de nuevo.',
    ),
  };
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
