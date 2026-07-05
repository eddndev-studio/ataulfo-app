import 'package:flutter/material.dart';

import '../tokens.dart';

/// Franja de aviso superior del design system: se pega al borde de la
/// pantalla, CONSUME el inset del status bar (su `SafeArea`) y, mientras está
/// visible, le retira ese padding al contenido de abajo para que ningún header
/// vuelva a reservarlo (evita el doble inset). Al ocultarse, el contenido
/// recupera su padding normal.
///
/// Es el primitivo de coordinación franja↔contenido: los avisos que abren la
/// pantalla (conectividad, verificación de correo) lo consumen en vez de
/// resolver el inset cada uno a su manera. Un aviso que vive DENTRO del layout
/// (no toca el borde superior) no lo necesita: para eso está AppNoticeBanner.
class AppTopBanner extends StatelessWidget {
  const AppTopBanner({
    super.key,
    required this.visible,
    required this.content,
    required this.child,
    this.color = AppTokens.surface2,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.sp3,
      vertical: AppTokens.sp2,
    ),
    this.bannerKey,
  });

  /// Muestra u oculta la franja (con un fundido corto). El aviso decide su
  /// visibilidad por estado; el primitivo solo coordina inset y transición.
  final bool visible;

  /// Contenido de la franja (fila de ícono + copy + acciones). El fondo, el
  /// inset y el padding los pone el primitivo.
  final Widget content;

  /// Contenido de la pantalla bajo la franja.
  final Widget child;

  /// Fondo de la franja; también pinta el área del status bar que reserva.
  final Color color;

  /// Padding interno del contenido de la franja (bajo el inset).
  final EdgeInsetsGeometry padding;

  /// Key del nodo visible de la franja, para que cada consumidor conserve su
  /// contrato de localización en tests.
  final Key? bannerKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: visible
              ? Material(
                  key:
                      bannerKey ??
                      const ValueKey<String>('app_top_banner.visible'),
                  color: color,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(padding: padding, child: content),
                    ),
                  ),
                )
              : const SizedBox(
                  key: ValueKey<String>('app_top_banner.hidden'),
                  width: double.infinity,
                ),
        ),
        Expanded(
          child: visible
              // La franja ya cubrió el status bar: sin esto, el contenido de
              // abajo lo reservaría de nuevo (doble padding).
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}
