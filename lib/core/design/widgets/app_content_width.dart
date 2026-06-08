import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Restringe el contenido a [AppTokens.maxContentWidth] y lo centra.
///
/// En pantallas anchas (desktop) evita que la UI se estire a todo lo ancho de
/// la ventana —se ve como una app de teléfono centrada— sin tener que
/// redimensionar la ventana en cada lanzamiento. En móvil/narrow es
/// transparente: el máximo supera el ancho real y el contenido llena la
/// pantalla. El fondo (glow) se pinta por fuera de este widget, así que llena
/// los costados libres.
///
/// `SizedBox.expand` fuerza al hijo a llenar la caja restringida (ancho =
/// max de contenido o el real, alto = completo); sin él, el navigator quedaría
/// con constraints sueltas de [Center] y no ocuparía el alto.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}
