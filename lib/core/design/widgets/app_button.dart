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
/// 14, label en DM Sans weight 600). `text` y `danger` reducen el padding
/// horizontal — viven inline (header de card, footer de modal) y no como
/// botones independientes.
class AppButton extends StatelessWidget {
  const AppButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
  }) : _variant = _AppButtonVariant.filled;

  const AppButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
  }) : _variant = _AppButtonVariant.tonal;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
  }) : _variant = _AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
    this.icon,
  }) : _variant = _AppButtonVariant.danger;

  final String label;
  final _AppButtonVariant _variant;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final colors = _colorsFor(_variant);
    final padding = _paddingFor(_variant);
    final radius = BorderRadius.circular(AppTokens.radiusButton);

    final content = Row(
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
          onTap: disabled ? null : onPressed,
          borderRadius: radius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            width: fullWidth ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: radius,
            ),
            child: content,
          ),
        ),
      ),
    );

    return Opacity(opacity: disabled ? 0.4 : 1.0, child: button);
  }

  static _AppButtonColors _colorsFor(_AppButtonVariant variant) {
    switch (variant) {
      case _AppButtonVariant.filled:
        return const _AppButtonColors(
          background: AppTokens.primary,
          foreground: Colors.white,
        );
      case _AppButtonVariant.tonal:
        return const _AppButtonColors(
          background: AppTokens.surface2,
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

class _AppButtonColors {
  const _AppButtonColors({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}
