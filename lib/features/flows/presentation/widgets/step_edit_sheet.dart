import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/failures/flows_failure.dart';
import '../bloc/flow_steps_bloc.dart';

/// Modal sheet de creación de un step TEXT (S11 F5a). Cuenta con tres
/// controles: `content` (TextField multiline), `delayMs` y `jitterPct`
/// (sliders), y `aiOnly` (switch).
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
  const StepEditSheet({super.key});

  @override
  State<StepEditSheet> createState() => _StepEditSheetState();
}

class _StepEditSheetState extends State<StepEditSheet> {
  static const int _maxDelayMs = 5 * 60 * 1000;
  static const int _maxJitterPct = 100;

  late final TextEditingController _contentCtrl;
  int _delayMs = 0;
  int _jitterPct = 0;
  bool _aiOnly = false;
  bool _didSubmit = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController();
    _contentCtrl.addListener(_onContentChanged);
  }

  void _onContentChanged() => setState(() {});

  @override
  void dispose() {
    _contentCtrl.removeListener(_onContentChanged);
    _contentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;
    _didSubmit = true;
    context.read<FlowStepsBloc>().add(
      FlowStepsAddRequested(
        content: content,
        delayMs: _delayMs,
        jitterPct: _jitterPct,
        aiOnly: _aiOnly,
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
                  Text('Nuevo paso', style: textTheme.titleLarge),
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
