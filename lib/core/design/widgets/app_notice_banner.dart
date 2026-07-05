import 'package:flutter/material.dart';

import '../tokens.dart';

/// Variantes del [AppNoticeBanner]. Privada — los callsites usan los
/// constructores con nombre (.info, .warning, .danger); el enum fuerza un
/// switch exhaustivo al resolver color e ícono por defecto.
enum _NoticeVariant { info, warning, danger }

/// Banner de aviso persistente del design system.
///
/// Sintetiza los avisos inline del producto (verificación de correo, alertas
/// del monitor, sin conexión) en un contenedor con radio y padding fijos: un
/// tint suave del color de la variante, un borde del mismo color, un ícono a la
/// izquierda, el mensaje y una acción opcional a la derecha.
///
/// A diferencia de un SnackBar es persistente: se queda hasta que el estado que
/// lo justifica cambia. Cada variante trae un ícono por defecto acorde a su
/// severidad, sustituible con [icon] cuando el contexto pide otro (p. ej. una
/// nube tachada para "sin conexión").
class AppNoticeBanner extends StatelessWidget {
  const AppNoticeBanner.info({
    super.key,
    required this.message,
    this.icon,
    this.action,
  }) : _variant = _NoticeVariant.info;

  const AppNoticeBanner.warning({
    super.key,
    required this.message,
    this.icon,
    this.action,
  }) : _variant = _NoticeVariant.warning;

  const AppNoticeBanner.danger({
    super.key,
    required this.message,
    this.icon,
    this.action,
  }) : _variant = _NoticeVariant.danger;

  final String message;

  /// Ícono opcional que sustituye al de la variante. Null ⇒ el default acorde
  /// a la severidad.
  final IconData? icon;

  /// Acción opcional al final (p. ej. un `AppButton.text` o un botón de cerrar).
  final Widget? action;

  final _NoticeVariant _variant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _color(_variant);
    return Container(
      padding: const EdgeInsets.all(AppTokens.sp3),
      decoration: BoxDecoration(
        // Tint suave del color de severidad + borde del mismo color: comunica el
        // tono sin teñir la fila entera.
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: color),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon ?? _defaultIcon(_variant), size: 20, color: color),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text1),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppTokens.sp2),
            action!,
          ],
        ],
      ),
    );
  }

  static Color _color(_NoticeVariant variant) {
    switch (variant) {
      case _NoticeVariant.info:
        return AppTokens.primary;
      case _NoticeVariant.warning:
        return AppTokens.warning;
      case _NoticeVariant.danger:
        return AppTokens.danger;
    }
  }

  static IconData _defaultIcon(_NoticeVariant variant) {
    switch (variant) {
      case _NoticeVariant.info:
        return Icons.info_outline;
      case _NoticeVariant.warning:
        return Icons.warning_amber_rounded;
      case _NoticeVariant.danger:
        return Icons.error_outline;
    }
  }
}
