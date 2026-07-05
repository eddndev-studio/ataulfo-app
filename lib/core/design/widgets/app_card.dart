import 'package:flutter/material.dart';

import '../tokens.dart';

/// Variantes visuales del [AppCard]. Privada al primitivo; los callsites usan
/// el constructor default o los nombrados (`.gradient`, `.glass`) — el enum
/// existe para forzar un switch exhaustivo al resolver la decoración.
enum _AppCardVariant { surface, gradient, glass, outline }

/// Primitivo Card del design system.
///
/// Componente estrella del producto — agrupa información relacionada con radio
/// 20 y padding generoso 20. Nunca lleva sombra (la jerarquía se construye con
/// surfaces, no con elevación). Si recibe [onTap], expone ripple/press feedback
/// con colores propios sobre el fondo oscuro.
///
/// Tres variantes comparten geometría:
/// - default: fondo `surface2`, la card de contenido habitual.
/// - `.gradient`: fill de marca (`brandGradient`) para la card destacada del
///   home; el gradiente vive en `gradient` y deja `color` nulo.
/// - `.glass`: fondo translúcido `glass` para cards sobre fondos vivos.
/// - `.outline`: sin relleno (transparente) con un hairline `divider`; delimita
///   la card sin competir con el fondo cuando el énfasis lo lleva otro elemento.
///
/// El constructor default recibe `padding` como `double` —la card de contenido
/// usa un padding uniforme—, mientras que los nombrados lo reciben como
/// `EdgeInsetsGeometry?` para permitir paddings asimétricos. El `EdgeInsets.all`
/// del default se arma en `build` y no en el initializer para que el constructor
/// siga siendo `const`.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    double padding = AppTokens.cardPadding,
  }) : _paddingValue = padding,
       _paddingGeometry = null,
       _variant = _AppCardVariant.surface;

  const AppCard.gradient({
    super.key,
    required this.child,
    this.onTap,
    EdgeInsetsGeometry? padding,
  }) : _paddingValue = null,
       _paddingGeometry = padding,
       _variant = _AppCardVariant.gradient;

  const AppCard.glass({
    super.key,
    required this.child,
    this.onTap,
    EdgeInsetsGeometry? padding,
  }) : _paddingValue = null,
       _paddingGeometry = padding,
       _variant = _AppCardVariant.glass;

  const AppCard.outline({
    super.key,
    required this.child,
    this.onTap,
    EdgeInsetsGeometry? padding,
  }) : _paddingValue = null,
       _paddingGeometry = padding,
       _variant = _AppCardVariant.outline;

  final Widget child;
  final VoidCallback? onTap;
  final double? _paddingValue;
  final EdgeInsetsGeometry? _paddingGeometry;
  final _AppCardVariant _variant;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    final padding =
        _paddingGeometry ??
        EdgeInsets.all(_paddingValue ?? AppTokens.cardPadding);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          padding: padding,
          decoration: _decorationFor(_variant, radius),
          child: child,
        ),
      ),
    );
  }

  /// Resuelve la decoración por variante. El gradiente y el color son
  /// mutuamente excluyentes en un [BoxDecoration]: la variante de marca pone
  /// el fill en `gradient` y deja `color` nulo.
  static BoxDecoration _decorationFor(
    _AppCardVariant variant,
    BorderRadius radius,
  ) {
    switch (variant) {
      case _AppCardVariant.surface:
        return BoxDecoration(color: AppTokens.surface2, borderRadius: radius);
      case _AppCardVariant.gradient:
        return BoxDecoration(
          gradient: AppTokens.brandGradient,
          borderRadius: radius,
        );
      case _AppCardVariant.glass:
        return BoxDecoration(color: AppTokens.glass, borderRadius: radius);
      case _AppCardVariant.outline:
        return BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: AppTokens.divider),
          borderRadius: radius,
        );
    }
  }
}
