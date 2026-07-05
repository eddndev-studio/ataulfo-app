import 'package:flutter/material.dart';

import '../tokens.dart';

/// Slider del design system.
///
/// Envuelve el [Slider] de Material con la tematización canónica del kit:
/// track activo y thumb en [AppTokens.primary], track inactivo en
/// [AppTokens.surface3] y overlay del gesto en primary al 12%. Existe para
/// que ningún call site re-declare un [SliderTheme] artesanal ni herede los
/// colores M3 por defecto, ajenos a la paleta.
///
/// API controlada, espejo de la del Slider de Material: [value] dentro de
/// [min]..[max], [divisions] opcional para pasos discretos y [onChanged]
/// nulo para deshabilitar el control (el Slider baja su opacidad solo).
class AppSlider extends StatelessWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppTokens.primary,
        inactiveTrackColor: AppTokens.surface3,
        thumbColor: AppTokens.primary,
        overlayColor: AppTokens.primary.withValues(alpha: 0.12),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}
