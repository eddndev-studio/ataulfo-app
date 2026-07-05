import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_choice_chip.dart';

/// Stepper de duración del design system.
///
/// El control correcto para «elige un retraso»: una lectura humana en el
/// centro («1 min 30 s»), botones −/+ a los lados y, opcionalmente, una fila
/// de [presets] como chips del kit para saltar directo a los valores típicos.
/// Reemplaza a los sliders de cientos de paradas, donde acertar un valor
/// exacto era cuestión de pulso.
///
/// El paso de los botones es **adaptativo a la magnitud**: fino donde un
/// segundo importa y grueso donde contarían de a uno sería un castigo —
/// 1 s bajo los 10 s, 5 s hasta el minuto, 30 s hasta los 10 min y 5 min en
/// adelante. Cada tap asienta el valor en la rejilla del paso vigente (62 s
/// sube a 90 s y baja a 60 s), así los valores quedan siempre redondos y el
/// −/+ es reversible.
///
/// El campo nunca emite fuera de `[min, max]`: los botones se recortan al
/// límite y quedan inertes al alcanzarlo; los presets también se recortan.
/// Widget controlado: no guarda estado, emite por [onChanged] y el consumer
/// decide. `onChanged` null deshabilita el control completo (opacidad 0.4).
class AppDurationField extends StatelessWidget {
  const AppDurationField({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = Duration.zero,
    this.max = const Duration(hours: 1),
    this.presets = const <Duration>[],
    this.keyPrefix = 'app_duration_field',
  });

  final Duration value;

  /// Recibe la nueva duración tras un tap en −/+ o en un preset. Null ⇒
  /// deshabilitado.
  final ValueChanged<Duration>? onChanged;

  final Duration min;
  final Duration max;

  /// Valores de salto directo, pintados como [AppChoiceChip] con su lectura
  /// («30 s», «5 min»). El chip cuyo valor iguala a [value] aparece
  /// seleccionado. Granularidad esperada: segundos enteros.
  final List<Duration> presets;

  /// Prefijo de las keys internas (`<keyPrefix>.decrement`, `.increment`,
  /// `.value`, `.preset.<segundos>`) para anclar pruebas de los consumers.
  final String keyPrefix;

  Duration _clamp(Duration d) {
    if (d < min) return min;
    if (d > max) return max;
    return d;
  }

  void _emit(Duration d) => onChanged!(_clamp(d));

  bool get _canDecrement => onChanged != null && value > min;
  bool get _canIncrement => onChanged != null && value < max;

  void _decrement() {
    final step = _stepDown(value).inSeconds;
    final seconds = value.inSeconds;
    // El múltiplo del paso estrictamente MENOR que el valor actual: un valor
    // fuera de la rejilla primero se asienta en ella hacia abajo.
    final prev = ((seconds - 1) ~/ step) * step;
    _emit(Duration(seconds: prev));
  }

  void _increment() {
    final step = _stepUp(value).inSeconds;
    final seconds = value.inSeconds;
    // El múltiplo del paso estrictamente MAYOR que el valor actual.
    final next = ((seconds ~/ step) + 1) * step;
    _emit(Duration(seconds: next));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final field = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StepButton(
              key: Key('$keyPrefix.decrement'),
              icon: Icons.remove,
              semanticsLabel: 'Reducir duración',
              onTap: _canDecrement ? _decrement : null,
            ),
            Expanded(
              child: Text(
                formatAppDuration(value),
                key: Key('$keyPrefix.value'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ),
            _StepButton(
              key: Key('$keyPrefix.increment'),
              icon: Icons.add,
              semanticsLabel: 'Aumentar duración',
              onTap: _canIncrement ? _increment : null,
            ),
          ],
        ),
        if (presets.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTokens.sp3),
          Wrap(
            spacing: AppTokens.sp2,
            runSpacing: AppTokens.sp2,
            children: <Widget>[
              for (final preset in presets)
                AppChoiceChip(
                  key: Key('$keyPrefix.preset.${preset.inSeconds}'),
                  label: formatAppDuration(preset),
                  selected: preset == value,
                  onSelected: onChanged == null ? null : (_) => _emit(preset),
                ),
            ],
          ),
        ],
      ],
    );

    // Disabled: atenuar el bloque completo, mismo idioma que AppTextField.
    return Opacity(opacity: onChanged == null ? 0.4 : 1.0, child: field);
  }
}

/// Paso al subir desde [d]: la magnitud actual decide el grano.
Duration _stepUp(Duration d) {
  if (d < const Duration(seconds: 10)) return const Duration(seconds: 1);
  if (d < const Duration(minutes: 1)) return const Duration(seconds: 5);
  if (d < const Duration(minutes: 10)) return const Duration(seconds: 30);
  return const Duration(minutes: 5);
}

/// Paso al bajar desde [d]. Los límites de tramo son INCLUSIVOS (≤) donde al
/// subir son exclusivos (<): así bajar desde una frontera usa el grano del
/// tramo inferior y el −/+ queda reversible (10 s − → 9 s, 9 s + → 10 s).
Duration _stepDown(Duration d) {
  if (d <= const Duration(seconds: 10)) return const Duration(seconds: 1);
  if (d <= const Duration(minutes: 1)) return const Duration(seconds: 5);
  if (d <= const Duration(minutes: 10)) return const Duration(seconds: 30);
  return const Duration(minutes: 5);
}

/// Lectura humana de una duración en h/min/s: componentes en cero se omiten
/// («1 min 30 s», «45 s», «1 h»); la duración cero se lee «0 s». Compartida
/// por la lectura central del campo y los labels de los presets para que
/// ambos hablen igual.
String formatAppDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final parts = <String>[
    if (hours > 0) '$hours h',
    if (minutes > 0) '$minutes min',
    if (seconds > 0) '$seconds s',
  ];
  if (parts.isEmpty) return '0 s';
  return parts.join(' ');
}

/// Botón circular −/+ del stepper: blanco táctil de 44px con el idioma
/// discreto del kit (borde hairline, glifo en `text2`). Inerte con [onTap]
/// null (límite alcanzado o campo deshabilitado), atenuado a 0.4.
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;

  static const double _diameter = 44.0;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          width: _diameter,
          height: _diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTokens.divider),
          ),
          child: Icon(icon, size: 20, color: AppTokens.text2),
        ),
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: button),
      ),
    );
  }
}
