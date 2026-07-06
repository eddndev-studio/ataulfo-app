import 'package:flutter/widgets.dart';

import '../motion.dart';
import '../tokens.dart';

/// Ícono que hace "pop" al montarse: entra encogido y asienta en su tamaño
/// con una curva de rebase ([AppTokens.easeSpring]). Pensado para estados de
/// selección que montan un widget nuevo al activarse — p. ej. el `activeIcon`
/// de una barra de navegación: cada vez que la tab se selecciona, su glifo
/// (variante filled) monta y salta.
///
/// Respeta [AppMotion]: apagado, el primer frame ya está en escala 1.0.
class AppIconPop extends StatelessWidget {
  const AppIconPop({super.key, required this.icon, this.from = 0.7});

  final IconData icon;

  /// Escala inicial del pop.
  final double from;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from, end: 1.0),
      duration: AppMotion.durationOf(context, AppTokens.durationBase),
      curve: AppTokens.easeSpring,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Icon(icon),
    );
  }
}
