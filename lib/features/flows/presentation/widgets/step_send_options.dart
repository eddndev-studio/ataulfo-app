import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/format_duration.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_choice_chip.dart';
import '../../../../core/design/widgets/app_disclosure_tile.dart';
import '../../../../core/design/widgets/app_notice_banner.dart';
import '../../../../core/design/widgets/app_slider.dart';
import '../../../../core/design/widgets/app_text_field.dart';

/// Modo de ejecución del paso. Mapea 1:1 a los flags excluyentes del wire
/// (`aiOnly`/`manualOnly`); el selector garantiza a-lo-más-uno-true, así el
/// 422 de exclusión del backend es inalcanzable desde este editor.
enum StepMode {
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

  const StepMode({
    required this.chipKey,
    required this.label,
    required this.helper,
  });

  final String chipKey;
  final String label;
  final String helper;

  static StepMode of({required bool aiOnly, required bool manualOnly}) {
    if (aiOnly) return StepMode.aiOnly;
    if (manualOnly) return StepMode.manualOnly;
    return StepMode.always;
  }
}

/// Sección "Opciones de envío" del sheet de composición: retraso, variación
/// y modo de ejecución tras divulgación progresiva — el default calla y el
/// paso común (escribir el mensaje y guardar) no atraviesa controles de
/// pacing que casi nunca cambia.
///
/// [showPacing] false (paso LABEL, que no envía al wire) esconde retraso y
/// variación, y la sección se titula "Opciones de ejecución": solo queda el
/// modo. [legacyDelayCured] abre la sección EXPANDIDA con un aviso honesto:
/// el paso traía el delay legacy 0 y guardar lo ajusta al piso de 1 s — la
/// curación deja de ser muda.
class StepSendOptions extends StatelessWidget {
  const StepSendOptions({
    super.key,
    required this.showPacing,
    required this.legacyDelayCured,
    required this.delayMs,
    required this.minDelayMs,
    required this.jitterController,
    required this.jitterInvalid,
    required this.mode,
    required this.enabled,
    required this.onDelayChanged,
    required this.onModeChanged,
  });

  final bool showPacing;
  final bool legacyDelayCured;
  final int delayMs;
  final int minDelayMs;

  /// Controller del campo de variación; lo posee el sheet para que el valor
  /// sobreviva al colapso del disclosure (que desmonta a sus hijos).
  final TextEditingController jitterController;

  /// True cuando el texto del campo excede el rango (0..100): el campo pinta
  /// el error y el sheet gatea el submit.
  final bool jitterInvalid;

  final StepMode mode;
  final bool enabled;
  final ValueChanged<int> onDelayChanged;
  final ValueChanged<StepMode> onModeChanged;

  /// Tope del slider de retraso (1 min). El backend admite valores mayores
  /// ya guardados (hasta 5 min): esos se CONSERVAN mientras el control no se
  /// arrastre — el slider pinta clavado al máximo, el readout dice el valor
  /// real y una caption explica que mover el control lo reemplaza.
  static const int _sliderMaxMs = 60000;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // True cuando el retraso guardado excede el tope del slider: el valor
    // exacto sobrevive al guardado porque onDelayChanged solo se emite al
    // arrastrar (el clamp de pintado no notifica).
    final delayBeyondSlider = delayMs > _sliderMaxMs;
    return AppDisclosureTile(
      key: const Key('step_edit.send_options'),
      icon: Icons.tune,
      title: showPacing ? 'Opciones de envío' : 'Opciones de ejecución',
      initiallyExpanded: legacyDelayCured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (legacyDelayCured) ...<Widget>[
            const AppNoticeBanner.info(
              key: Key('step_edit.legacy_delay_notice'),
              message:
                  'Este paso enviaba sin retraso; al guardar se ajustará '
                  'al mínimo de 1 s.',
            ),
            const SizedBox(height: AppTokens.sp4),
          ],
          if (showPacing) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Retraso',
                  style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
                ),
                // La lectura humana del valor VIGENTE, que puede exceder el
                // rango del slider (retraso legado): siempre dice la verdad.
                Text(
                  formatAppDuration(Duration(milliseconds: delayMs)),
                  key: const Key('step_edit.delay.value'),
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
            AppSlider(
              key: const Key('step_edit.delay.slider'),
              // El pintado se acota al rango; el valor real vive en delayMs.
              value: delayMs.clamp(minDelayMs, _sliderMaxMs) / 1000,
              min: minDelayMs / 1000,
              max: _sliderMaxMs / 1000,
              // Paradas de 1 s en todo el rango [1 s, 60 s].
              divisions: (_sliderMaxMs - minDelayMs) ~/ 1000,
              onChanged: enabled
                  ? (v) => onDelayChanged(v.round() * 1000)
                  : null,
            ),
            const SizedBox(height: AppTokens.sp1),
            Text(
              'Cuánto espera el Asistente antes de enviar el paso (1 s a 1 min).',
              style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
            ),
            if (delayBeyondSlider) ...<Widget>[
              const SizedBox(height: AppTokens.sp1),
              Text(
                'Este paso conserva su retraso actual; mueve el control '
                'para cambiarlo.',
                key: const Key('step_edit.delay.legacy_range'),
                style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
              ),
            ],
            const SizedBox(height: AppTokens.sp4),
            AppTextField(
              key: const Key('step_edit.jitter'),
              label: 'Variación (%)',
              hint: '0',
              controller: jitterController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              helperText:
                  'Aleatoriedad sobre el retraso para sonar humano (±%).',
              errorText: jitterInvalid ? 'La variación va de 0 a 100.' : null,
            ),
            const SizedBox(height: AppTokens.sp4),
          ],
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              for (final m in StepMode.values)
                AppChoiceChip(
                  key: Key(m.chipKey),
                  label: m.label,
                  selected: mode == m,
                  onSelected: enabled ? (_) => onModeChanged(m) : null,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.sp2),
          Text(
            mode.helper,
            style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        ],
      ),
    );
  }
}
