import 'package:flutter/material.dart';

import '../tokens.dart';

/// Glifo circular del design system: un tile (paridad con AppEntityIcon, 44px)
/// con un ícono centrado (tamaño `size * 0.5`).
///
/// Dos vías:
/// - **Cromática** (constructor por defecto): el fondo es el COLOR de la
///   entidad a baja alpha y el ícono en el color pleno. Da presencia a
///   entidades cuya identidad ES un color (etiquetas internas, etiquetas de
///   WhatsApp) sin gritar sobre el tema oscuro.
/// - **Neutra** ([AppSwatchIcon.neutral]): relleno [AppTokens.surface3] opaco
///   e ícono [AppTokens.text2]. Para destinos sin identidad cromática propia
///   (el círculo de acción del menú de adjuntar, p. ej.).
class AppSwatchIcon extends StatelessWidget {
  const AppSwatchIcon({
    super.key,
    required this.color,
    this.icon = Icons.label_outline,
    this.size = 44,
  }) : _neutral = false;

  /// Vía neutra: círculo [AppTokens.surface3] con ícono [AppTokens.text2], sin
  /// identidad cromática. El [color] queda ignorado.
  const AppSwatchIcon.neutral({super.key, required this.icon, this.size = 44})
    : color = AppTokens.text2,
      _neutral = true;

  /// Color de la entidad (hex de Label interno ya parseado, o el resuelto de
  /// la paleta WhatsApp). Ignorado en la vía neutra.
  final Color color;
  final IconData icon;
  final double size;

  final bool _neutral;

  @override
  Widget build(BuildContext context) {
    final background = _neutral
        ? AppTokens.surface3
        : color.withValues(alpha: 0.18);
    final foreground = _neutral ? AppTokens.text2 : color;
    return Container(
      key: const Key('app_swatch_icon.tile'),
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}
