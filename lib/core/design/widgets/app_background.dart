import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Fondo absoluto de la app.
///
/// Pinta el glow radial cálido del kit ([AppTokens.backgroundGlow]) que nace
/// arriba y se disuelve en [AppTokens.bgBase]. Es el lienzo común sobre el que
/// se montan las pantallas: sus app bars van transparentes y su contenido
/// scrollea encima, mientras el glow queda fijo a la vista.
///
/// No introduce padding ni safe-area: solo el lienzo. El [child] (normalmente
/// el cuerpo de un Scaffold con `backgroundColor: Colors.transparent`) define
/// el tamaño y, al recibir las constraints completas del body, hace que el
/// glow ocupe toda la pantalla.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTokens.backgroundGlow),
      child: child,
    );
  }
}
