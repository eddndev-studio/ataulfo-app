import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo Checkbox del design system.
///
/// Caja redondeada (radio [AppTokens.radiusSm]) de lado ~24 envuelta en un
/// área tappable de 48 — el control visible es pequeño pero el blanco de
/// toque cumple el mínimo de accesibilidad. `unchecked` se delinea con un
/// borde [AppTokens.divider] sobre fondo transparente; `checked` se rellena
/// con [AppTokens.primary] y muestra el check en [AppTokens.onPrimary] (el
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
        // Vacío: solo el borde delinea la caja contra la superficie.
        color: value ? AppTokens.primary : Colors.transparent,
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

    return Opacity(opacity: disabled ? 0.4 : 1.0, child: control);
  }
}
