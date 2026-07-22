import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_press_scale.dart';

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
///
/// Feedback táctil: mientras está presionado encoge sutilmente
/// ([AppPressScale], conducido por el highlight del InkWell — arena-aware,
/// así un scroll que arranca encima no lo dispara) y regresa al soltar.
class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();

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

class _AppButtonState extends State<AppButton> {
  /// Highlight del InkWell en vivo: presiona→true, suelta/cancela→false.
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final colors = AppButton._colorsFor(widget._variant);
    final padding = AppButton._paddingFor(widget._variant);
    final radius = BorderRadius.circular(AppTokens.radiusButton);
    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTokens.fontSans,
        fontSize: AppTokens.bodyLSize,
        fontWeight: FontWeight.w600,
        color: colors.foreground,
      ),
    );

    final content = widget.loading
        ? Row(
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
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
            mainAxisSize: widget.fullWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 20, color: colors.foreground),
                const SizedBox(width: 8),
              ],
              // En fullWidth el label cede al ancho disponible y puede crecer
              // a dos líneas. Esto conserva el copy y el escalado de texto en
              // teléfonos compactos sin desbordar el Row del botón.
              if (widget.fullWidth) Flexible(child: label) else label,
            ],
          );

    final button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // loading bloquea el tap sin nullificar onPressed externo — el
          // consumer pasa el callback inalterado y el botón decide.
          onTap: (disabled || widget.loading) ? null : widget.onPressed,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            width: widget.fullWidth ? double.infinity : null,
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
      label: widget.label,
      onTap: (disabled || widget.loading) ? null : widget.onPressed,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: AppPressScale(pressed: _pressed, child: button),
        ),
      ),
    );
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
