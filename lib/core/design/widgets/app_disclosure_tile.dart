import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo colapsable del design system: ícono + título en una fila que, al
/// tocarse, revela un cuerpo arbitrario. Envuelve el [ExpansionTile] de Material
/// sobre una superficie `surface2` redondeada y silencia el divisor propio del
/// tile (que dibuja una línea al expandir), de modo que la revelación se lee
/// como parte de la misma tarjeta y no como un separador de lista.
///
/// El título va en `labelMedium/text2` y el ícono en `text2` a 18px: el tile es
/// secundario por diseño (telemetría, detalles opcionales), no compite con el
/// contenido principal.
class AppDisclosureTile extends StatelessWidget {
  const AppDisclosureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // El fondo lo da un Material (no un DecoratedBox con color): el ListTile
    // interno del ExpansionTile pinta su superficie y tinte sobre el Material
    // ancestro más cercano; si el color viviera en un DecoratedBox intermedio
    // lo taparía.
    return Material(
      color: AppTokens.surface2,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            0,
            AppTokens.sp3,
            AppTokens.sp3,
          ),
          leading: Icon(icon, size: 18, color: AppTokens.text2),
          title: Text(
            title,
            style: textTheme.labelMedium?.copyWith(color: AppTokens.text2),
          ),
          children: <Widget>[child],
        ),
      ),
    );
  }
}
