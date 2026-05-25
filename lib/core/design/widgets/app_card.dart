import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo Card del design system.
///
/// Componente estrella del producto — agrupa información relacionada con
/// fondo `surface2`, radio 20 y padding generoso 20. Nunca lleva sombra
/// (la jerarquía se construye con surfaces, no con elevación). Si
/// recibe [onTap], expone ripple/press feedback con colores propios sobre
/// el fondo oscuro.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppTokens.cardPadding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}
