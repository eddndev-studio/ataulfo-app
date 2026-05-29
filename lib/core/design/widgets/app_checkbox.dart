import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo Checkbox del design system.
///
/// Caja redondeada (radio [AppTokens.radiusSm]) de lado ~24 envuelta en un
/// área tappable de 48 — el control visible es pequeño pero el blanco de
/// toque cumple el mínimo de accesibilidad. `unchecked` se rellena con
/// [AppTokens.surface3] y se delinea con un borde [AppTokens.divider]: la
/// caja se lee llena y elevada, no hueca; `checked` se rellena con
/// [AppTokens.primary] y muestra el check en [AppTokens.onPrimary] (el
/// amarillo exige primer plano oscuro para contraste).
///
/// El componente es controlado: no guarda estado. El tap emite
/// `onChanged(!value)` y el padre decide el nuevo valor. Con `onChanged` null
/// el control queda inerte (tap nulo) y atenuado, igual que [AppButton].
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Lado de la caja visible. El hit-target lo expande a 48 sin agrandarla.
  static const double _boxSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    final radius = BorderRadius.circular(AppTokens.radiusSm);

    final box = Container(
      width: _boxSize,
      height: _boxSize,
      decoration: BoxDecoration(
        // Vacío: superficie elevada con borde que delinea la caja llena.
        color: value ? AppTokens.primary : AppTokens.surface3,
        borderRadius: radius,
        border: value ? null : Border.all(color: AppTokens.divider),
      ),
      child: value
          ? const Icon(
              Icons.check,
              size: 18,
              color: AppTokens.onPrimary,
            )
          : null,
    );

    final control = SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : () => onChanged!(!value),
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Center(child: box),
        ),
      ),
    );

    // Un único nodo semántico de casilla: ExcludeSemantics colapsa el nodo de
    // botón que aporta el InkWell (evita anunciar "casilla que contiene un
    // botón"); el rol y el estado los porta este Semantics, que además es
    // operable por accesibilidad vía onTap.
    return Semantics(
      container: true,
      checked: value,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: control),
      ),
    );
  }
}
