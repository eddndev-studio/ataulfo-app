import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Fondo absoluto de la app: [AppTokens.bgBase] sólido.
///
/// Es el lienzo común sobre el que se montan las pantallas: sus app bars van
/// transparentes y su contenido scrollea encima. Oscuro y plano a propósito —
/// el color cálido de la marca vive como FILL de componentes (headers de
/// gradiente, botones), nunca como fondo: un lienzo neutro deja respirar las
/// superficies y mejora el contraste percibido.
///
/// No introduce padding ni safe-area: solo el lienzo. `StackFit.expand`
/// fuerza al lienzo —y al child— a ocupar las constraints completas del body.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: AppTokens.bgBase),
        child,
      ],
    );
  }
}
