import 'package:flutter/material.dart';

import '../tokens.dart';

/// Chip de selección única/múltiple del design system (ChoiceChip del kit).
///
/// Dos estados mutuamente excluyentes según [selected]:
/// - **unselected**: superficie transparente con borde hairline ([AppTokens
///   .divider]) y label en [AppTokens.text2]. Es una opción latente.
/// - **selected**: TINTE de marca (fondo [AppTokens.primary] al 16% + borde y
///   label/ícono en [AppTokens.primary]) con un check a la izquierda. Es
///   deliberadamente discreto: un chip de selección NO debe usar el fill
///   amarillo pleno —eso es lenguaje de CTA— y competir con los botones de
///   acción. El guiño cálido comunica "activo" sin gritar.
///
/// Radio [AppTokens.radiusPill] (cápsula) — en línea con el resto de la
/// familia de toggles (botones, pills): un borde cuadrado disonaba con los
/// demás componentes. La distinción filtro/acción la dan el tinte y el borde,
/// no la forma. El borde de 1px existe en ambos estados (divider / primary)
/// para que la geometría no salte al seleccionar. `onSelected` null deshabilita
/// el chip: baja el tinte a 0.4 y bloquea el tap.
///
/// El tap no alterna el estado por sí mismo: emite `onSelected(!selected)` y
/// es el consumer quien decide el nuevo [selected]. Así el chip es controlado,
/// igual que el resto de la familia de toggles, y soporta tanto selección
/// única como múltiple sin estado interno.
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final disabled = onSelected == null;
    final radius = BorderRadius.circular(AppTokens.radiusPill);
    final foreground = selected ? AppTokens.primary : AppTokens.text2;

    final chip = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : () => onSelected!(!selected),
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.sp3,
              vertical: AppTokens.sp2,
            ),
            decoration: BoxDecoration(
              // Selección discreta: TINTE de marca (primary al 16%), no el fill
              // amarillo pleno tipo CTA. Sin selección, transparente. El borde
              // de 1px existe siempre (primary / divider) para que la geometría
              // no salte al seleccionar.
              color: selected
                  ? AppTokens.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppTokens.primary : AppTokens.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  Icon(Icons.check, size: 18, color: foreground),
                  const SizedBox(width: AppTokens.sp1),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTokens.fontSans,
                    fontSize: AppTokens.bodyMSize,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Un único nodo de botón seleccionable: ExcludeSemantics colapsa el nodo
    // del InkWell y el del label; este Semantics porta rol (button), estado
    // (selected), etiqueta y operabilidad por accesibilidad.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: !disabled,
      label: label,
      onTap: disabled ? null : () => onSelected!(!selected),
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: chip),
      ),
    );
  }
}
