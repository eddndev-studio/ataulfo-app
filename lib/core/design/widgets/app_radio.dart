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
/// estado apagado rellena el interior con [AppTokens.surface3] y un borde
/// [AppTokens.text2] visible; el encendido invierte la figura — el anillo se
/// rellena de marca ([AppTokens.primary]) y un punto oscuro
/// ([AppTokens.onPrimary]) ancla el centro, garantizando contraste sobre el
/// amarillo.
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

    final ring = Container(
      key: const ValueKey('app_radio.ring'),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Seleccionado: relleno de marca. Apagado: superficie elevada con un
        // borde neutral visible que dibuja el contorno del control.
        color: selected ? AppTokens.primary : AppTokens.surface3,
        border: Border.all(
          color: selected ? AppTokens.primary : AppTokens.text2,
          width: 2,
        ),
      ),
      // El punto interior solo existe en estado seleccionado y va oscuro
      // ([onPrimary]) para resaltar contra el relleno amarillo.
      child: selected
          ? Center(
              child: Container(
                key: const ValueKey('app_radio.dot'),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTokens.onPrimary,
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

    // Un único nodo de radio en grupo exclusivo: ExcludeSemantics colapsa el
    // nodo de botón del InkWell; el rol/estado (checked = seleccionado) y la
    // operabilidad por accesibilidad los porta este Semantics.
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: !disabled,
      onTap: disabled ? null : () => onChanged!(value),
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: control),
      ),
    );
  }
}
