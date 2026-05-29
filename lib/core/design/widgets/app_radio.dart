import 'package:flutter/material.dart';

import '../tokens.dart';

/// Primitivo Radio del design system.
///
/// Selección exclusiva dentro de un grupo: el control está seleccionado
/// cuando su [value] coincide con el [groupValue] del grupo. El idioma sigue
/// al `Radio` de Flutter — el callback recibe el propio [value], y el padre
/// decide cómo actualizar el `groupValue`.
///
/// Geometría: anillo visible de 24 centrado en un área tappable de 48 para
/// cumplir el mínimo de hit-target sin agrandar el control a la vista. El
/// estado apagado pinta un borde neutral ([AppTokens.divider]); el encendido
/// pasa el borde a [AppTokens.primary] y rellena un punto interior de marca.
///
/// `onChanged` nulo deshabilita: baja la opacidad y deja el control inerte
/// (el tap no dispara nada).
class AppRadio<T> extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  /// Valor que representa este control dentro del grupo.
  final T value;

  /// Valor actualmente seleccionado del grupo. `selected` si iguala a [value].
  final T? groupValue;

  /// Callback de selección. Nulo deshabilita el control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    final selected = value == groupValue;
    final borderColor = selected ? AppTokens.primary : AppTokens.divider;

    final ring = Container(
      key: const ValueKey('app_radio.ring'),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      // El punto interior solo existe en estado seleccionado.
      child: selected
          ? Center(
              child: Container(
                key: const ValueKey('app_radio.dot'),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTokens.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );

    final control = SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Sin callback el control queda inerte; el splash cubre todo el
          // hit-target de 48, no solo el anillo de 24.
          onTap: disabled ? null : () => onChanged!(value),
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Center(child: ring),
        ),
      ),
    );

    return Opacity(opacity: disabled ? 0.4 : 1.0, child: control);
  }
}
