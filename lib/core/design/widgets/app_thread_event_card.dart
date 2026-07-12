import 'package:flutter/material.dart';

import '../tokens.dart';

/// Contenedor canónico de un "evento del hilo": un registro centrado de algo que
/// pasó en la conversación (una herramienta que corrió, un cambio en el
/// workspace, una confirmación pendiente) — no una burbuja de nadie. Es el
/// idioma visual compartido entre el entrenador y el asistente: superficie
/// `surface2`, borde hairline (`divider`, o `danger` cuando el evento es un
/// fallo) y radio de cápsula colapsado que crece a radio de tarjeta al
/// expandir.
///
/// Solo aporta la caja: el contenido (encabezado, detalle) lo compone el
/// llamador, típicamente con [AppThreadEventHeader] arriba.
class AppThreadEventCard extends StatelessWidget {
  const AppThreadEventCard({
    super.key,
    required this.child,
    this.error = false,
    this.expanded = false,
    this.fill = false,
    this.onTap,
    this.maxWidth,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.sp3,
      vertical: AppTokens.sp2,
    ),
  });

  final Widget child;

  /// Tiñe el borde en `danger`: el evento fue un fallo.
  final bool error;

  /// Radio de tarjeta en vez de cápsula: la tarjeta está expandida.
  final bool expanded;

  /// Ocupa el ancho disponible (hasta [maxWidth]) en vez de abrazar el
  /// contenido. Lo usan las tarjetas con acciones alineadas al borde.
  final bool fill;

  final VoidCallback? onTap;

  /// Tope de ancho para el contenido largo (envuelve dentro de él). `null` deja
  /// que la tarjeta crezca con su contenido (acotada por el padding de la lista).
  final double? maxWidth;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget box = Container(
      width: fill ? double.infinity : null,
      margin: const EdgeInsets.symmetric(vertical: AppTokens.sp1),
      padding: padding,
      decoration: BoxDecoration(
        color: AppTokens.surface2,
        borderRadius: BorderRadius.circular(
          expanded ? AppTokens.radiusCard : AppTokens.radiusPill,
        ),
        border: Border.all(color: error ? AppTokens.danger : AppTokens.divider),
      ),
      child: child,
    );
    final tap = onTap;
    if (tap != null) {
      box = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: box,
      );
    }
    final cap = maxWidth;
    if (cap != null) {
      box = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: box,
      );
    }
    return Align(alignment: Alignment.center, child: box);
  }
}

/// Encabezado de un evento del hilo: ícono + label y, opcionalmente, un chevron
/// de expandir/colapsar. Es la fila que corona una [AppThreadEventCard]. El
/// ícono va en `primary` (o `danger` con [error]); el label en `labelMedium`
/// salvo que se pase un estilo propio (los textos multilínea de error/
/// confirmación usan `bodySmall`).
class AppThreadEventHeader extends StatelessWidget {
  const AppThreadEventHeader({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.error = false,
    this.showChevron = false,
    this.expanded = false,
    this.chevronKey,
    this.labelStyle,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.leading,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final bool error;
  final bool showChevron;
  final bool expanded;
  final Key? chevronKey;
  final TextStyle? labelStyle;
  final CrossAxisAlignment crossAxisAlignment;

  /// Widget que sustituye al [icon] (p. ej. el TypingBubble que late en la
  /// mini-traza del hilo). `null` ⇒ el ícono de siempre.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        labelStyle ??
        theme.textTheme.labelMedium?.copyWith(color: AppTokens.text1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        leading ??
            Icon(
              icon,
              size: 16,
              color:
                  iconColor ?? (error ? AppTokens.danger : AppTokens.primary),
            ),
        const SizedBox(width: AppTokens.sp2),
        Flexible(child: Text(label, style: style)),
        if (showChevron) ...<Widget>[
          const SizedBox(width: AppTokens.sp1),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            key: chevronKey,
            size: 16,
            color: AppTokens.text2,
          ),
        ],
      ],
    );
  }
}
