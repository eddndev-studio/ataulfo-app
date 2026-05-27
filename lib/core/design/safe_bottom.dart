import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Insets seguros para el fondo del contenido, derivados del `MediaQuery`
/// que ya ve el widget.
///
/// El padding inferior de Android no es uniforme: depende de qué nav está
/// activa (3-button vs gesture) y de si hay teclado virtual encima. Las
/// dos primitivas distinguen el caso para que cada widget elija el
/// correcto sin recalcular el `max` a mano:
///
/// - [safeBottomInset] respeta solo la gesture-nav del sistema. Es lo que
///   una page con scroll necesita para que el último item no quede
///   debajo de la barra. Ignora el teclado a propósito (la page no se
///   redimensiona al abrir el teclado; el `Scaffold` ya empuja el
///   contenido hacia arriba).
///
/// - [sheetBottomInset] devuelve el máximo entre el teclado virtual y la
///   gesture-nav. Es lo que un `showModalBottomSheet` necesita: cuando
///   el teclado está abierto, viaja con él (`viewInsets.bottom > 0`);
///   cuando se cierra, vuelve a respetar la gesture-nav.
extension SafeBottomContext on BuildContext {
  /// Espacio inferior reservado por la gesture-nav del sistema.
  ///
  /// Aplicar al fondo del scroll de una page asegura que el último item
  /// sea accesible por encima de la nav bar. NO incluye `viewInsets.bottom`
  /// porque la page típica no se redimensiona con el teclado.
  double get safeBottomInset => MediaQuery.viewPaddingOf(this).bottom;

  /// Espacio inferior seguro para un sheet o modal: el máximo entre el
  /// teclado virtual (`viewInsets.bottom`, > 0 sólo con teclado abierto)
  /// y la gesture-nav del sistema (`viewPadding.bottom`, > 0 cuando hay
  /// nav). El operador siempre puede ver lo que está escribiendo y los
  /// botones de acción quedan por encima de ambos.
  double get sheetBottomInset {
    final media = MediaQuery.of(this);
    return math.max(media.viewInsets.bottom, media.viewPadding.bottom);
  }
}
