import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Empuja un visor fullscreen con la transición compartida de media: ruta
/// TRANSPARENTE con fade sobre el hilo (el fondo lo pinta [ViewerShell]).
/// La usan el visor de imagen y el reproductor de video: una sola manera de
/// entrar y salir de "ver media en grande".
Future<void> showViewerRoute(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Cascarón compartido de los visores fullscreen (imagen y video): fondo
/// oscuro, botón de cerrar arriba a la derecha y tap-en-el-fondo para
/// descartar. El contenido va encima y ABSORBE sus propios taps (la foto con
/// zoom o la superficie play/pausa del video): un toque sobre el contenido
/// jamás cierra el visor por accidente.
class ViewerShell extends StatelessWidget {
  const ViewerShell({
    required this.child,
    this.backgroundKey = const Key('media_viewer'),
    this.dismissKey = const Key('media_viewer.dismiss'),
    this.closeKey = const Key('media_viewer.close'),
    super.key,
  });

  final Widget child;

  /// Llaves estables para tests/telemetría; el reproductor de video conserva
  /// las suyas históricas.
  final Key backgroundKey;
  final Key dismissKey;
  final Key closeKey;

  @override
  Widget build(BuildContext context) {
    // Material transparente: la ruta es PageRouteBuilder sin Scaffold y los
    // botones de Material lo exigen como ancestro.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        key: dismissKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          key: backgroundKey,
          color: Colors.black.withValues(alpha: 0.92),
          alignment: Alignment.center,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: child),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    key: closeKey,
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: AppTokens.text1),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
