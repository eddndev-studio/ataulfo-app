import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Fondo absoluto de la app.
///
/// Pinta el glow "amanecer" del kit ([AppTokens.backgroundGlowLayers]): varias
/// capas radiales cálidas que nacen del borde superior y se disuelven en
/// [AppTokens.bgBase]. Es el lienzo común sobre el que se montan las pantallas:
/// sus app bars van transparentes y su contenido scrollea encima, mientras el
/// glow queda fijo a la vista.
///
/// No introduce padding ni safe-area: solo el lienzo. El [child] (normalmente
/// el cuerpo de un Scaffold con `backgroundColor: Colors.transparent`) se monta
/// encima del glow; `StackFit.expand` fuerza a todas las capas —y al child— a
/// ocupar las constraints completas del body, así el glow cubre toda la vista.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Lienzo base oscuro; las capas cálidas se pintan encima en orden.
        const ColoredBox(color: AppTokens.bgBase),
        for (final gradient in AppTokens.backgroundGlowLayers)
          DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        // El contenido va al tope de la pila (encima del glow).
        child,
      ],
    );
  }
}
