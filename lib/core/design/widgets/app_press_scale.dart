import 'package:flutter/widgets.dart';

import '../motion.dart';
import '../tokens.dart';

/// Feedback táctil del kit: encoge sutilmente a su hijo mientras está
/// presionado y regresa al soltar — el "hundimiento" que hace sentir vivo un
/// control junto al ripple.
///
/// El consumidor conduce [pressed] desde `InkWell.onHighlightChanged`, no
/// desde punteros crudos: el highlight es arena-aware (un drag de scroll que
/// arranca encima del control lo cancela), así las filas dentro de listas no
/// laten al scrollear.
///
/// Respeta [AppMotion]: apagado, la escala queda clavada en 1.0.
class AppPressScale extends StatelessWidget {
  const AppPressScale({
    super.key,
    required this.pressed,
    this.scale = 0.97,
    required this.child,
  });

  final bool pressed;

  /// Cuánto encoge presionado. Superficies grandes (tiles) usan valores más
  /// cercanos a 1.0 para que el gesto no se sienta exagerado.
  final double scale;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animate = AppMotion.enabledOf(context);
    return AnimatedScale(
      scale: animate && pressed ? scale : 1.0,
      duration: AppMotion.durationOf(context, AppTokens.durationFast),
      curve: AppTokens.ease,
      child: child,
    );
  }
}
