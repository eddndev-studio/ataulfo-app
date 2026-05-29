import 'package:flutter/material.dart';

import '../tokens.dart';

/// Variantes visuales del [AppButton]. Privada al primitivo; los callsites
/// usan los constructores con nombre (`.filled`, `.tonal`, `.text`,
/// `.danger`) — el enum existe para forzar switch exhaustivo dentro del
/// build cuando resuelve colores y padding.
enum _AppButtonVariant { filled, tonal, text, danger }

/// Primitivo Button del design system.
///
/// Cuatro variantes con la misma geometría base (altura mínima 48, radio
/// pill, label en DM Sans weight 600). `filled` se pinta con el gradiente de
/// marca y lleva el primer plano oscuro (`onPrimary`) que el amarillo exige
/// para contraste; `text` y `danger` reducen el padding horizontal — viven
/// inline (header de card, footer de modal) y no como botones independientes.
///
/// El estado `loading` reemplaza el label por un spinner inline y bloquea
/// el tap internamente sin nullificar `onPressed` — los formularios pueden
/// pasar el callback sin gate manual `!submitting` en cada page.
class AppButton extends StatelessWidget {
  const AppButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  }) : _variant = _AppButtonVariant.filled;

  const AppButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  }) : _variant = _AppButtonVariant.tonal;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  }) : _variant = _AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  }) : _variant = _AppButtonVariant.danger;

  final String label;
  final _AppButtonVariant _variant;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final colors = _colorsFor(_variant);
    final padding = _paddingFor(_variant);
    final radius = BorderRadius.circular(AppTokens.radiusButton);

    final content = loading
        ? Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
                ),
              ),
            ],
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: colors.foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTokens.fontSans,
                  fontSize: AppTokens.bodyLSize,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ],
          );

    final button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // loading bloquea el tap sin nullificar onPressed externo — el
          // consumer pasa el callback inalterado y el botón decide.
          onTap: (disabled || loading) ? null : onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            width: fullWidth ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              // El relleno cálido es un gradiente, no un color sólido: cuando
              // la variante define [gradient], `color` queda en null para que
              // la BoxDecoration pinte con la rampa de marca.
              color: colors.background,
              gradient: colors.gradient,
              borderRadius: radius,
            ),
            child: content,
          ),
        ),
      ),
    );

    // Un único nodo de botón con su etiqueta: ExcludeSemantics colapsa el nodo
    // del InkWell y el del label (que en loading desaparece de la vista pero
    // sigue describiendo la acción). Loading bloquea el tap igual que disabled.
    // Loading conserva opacity 1.0: el spinner ya comunica el estado y bajar el
    // tinte agregaría ruido visual sobre algo que ya se ve.
    return Semantics(
      container: true,
      button: true,
      enabled: !disabled,
      label: label,
      onTap: (disabled || loading) ? null : onPressed,
      child: ExcludeSemantics(
        child: Opacity(opacity: disabled ? 0.4 : 1.0, child: button),
      ),
    );
  }

  static _AppButtonColors _colorsFor(_AppButtonVariant variant) {
    switch (variant) {
      case _AppButtonVariant.filled:
        // El amarillo exige primer plano oscuro: onPrimary, nunca blanco.
        return const _AppButtonColors(
          gradient: AppTokens.brandGradient,
          foreground: AppTokens.onPrimary,
        );
      case _AppButtonVariant.tonal:
        return const _AppButtonColors(
          background: AppTokens.surface3,
          foreground: AppTokens.text1,
        );
      case _AppButtonVariant.text:
        return const _AppButtonColors(
          background: Colors.transparent,
          foreground: AppTokens.primary,
        );
      case _AppButtonVariant.danger:
        return const _AppButtonColors(
          background: Colors.transparent,
          foreground: AppTokens.danger,
        );
    }
  }

  static EdgeInsets _paddingFor(_AppButtonVariant variant) {
    switch (variant) {
      case _AppButtonVariant.filled:
      case _AppButtonVariant.tonal:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 12);
      case _AppButtonVariant.text:
      case _AppButtonVariant.danger:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 12);
    }
  }
}

/// Resolución de color por variante. Una variante define [gradient] (relleno
/// cálido de marca, con [background] en null) o [background] (relleno sólido o
/// transparente, sin [gradient]); nunca ambos a la vez.
class _AppButtonColors {
  const _AppButtonColors({
    this.background,
    this.gradient,
    required this.foreground,
  });
  final Color? background;
  final Gradient? gradient;
  final Color foreground;
}
