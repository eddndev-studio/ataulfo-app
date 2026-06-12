import 'package:flutter/material.dart';

/// Glifo de identidad cromática del design system: un tile circular (paridad
/// con AppEntityIcon, 44px) cuyo fondo es el COLOR de la entidad a baja alpha
/// y el icono en el color pleno. Da presencia a entidades cuya identidad ES un
/// color (etiquetas internas, etiquetas de WhatsApp) sin gritar sobre el tema
/// oscuro — un dot pequeño no comunica esa identidad en una card.
class AppSwatchIcon extends StatelessWidget {
  const AppSwatchIcon({
    super.key,
    required this.color,
    this.icon = Icons.label_outline,
    this.size = 44,
  });

  /// Color de la entidad (hex de Label interno ya parseado, o el resuelto de
  /// la paleta WhatsApp).
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('app_swatch_icon.tile'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
