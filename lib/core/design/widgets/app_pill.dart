import 'package:flutter/material.dart';

import '../tokens.dart';

/// Color del dot opcional que aparece a la izquierda del label.
enum AppPillDot { active, paused, danger }

/// Variantes visuales del [AppPill]. Privada — los callsites usan los
/// constructores con nombre (.primary, .neutral, .danger, .outline).
enum _AppPillVariant { primary, neutral, danger, outline }

/// Primitivo Pill / Badge del design system.
///
/// Reemplaza al `Chip` de Material: no respeta el theme legacy (tokens
/// duros), tipografía caption 12/16/500 y padding 4/10 idénticos en todas
/// las variantes. El dot opcional sirve como indicador de estado al lado
/// del label sin necesidad de iconos extra.
class AppPill extends StatelessWidget {
  const AppPill.primary({super.key, required this.label, this.dot})
    : _variant = _AppPillVariant.primary;

  const AppPill.neutral({super.key, required this.label, this.dot})
    : _variant = _AppPillVariant.neutral;

  const AppPill.danger({super.key, required this.label, this.dot})
    : _variant = _AppPillVariant.danger;

  const AppPill.outline({super.key, required this.label, this.dot})
    : _variant = _AppPillVariant.outline;

  final String label;
  final _AppPillVariant _variant;
  final AppPillDot? dot;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(_variant);
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          border: colors.border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (dot != null) ...<Widget>[
              Container(
                key: const ValueKey<String>('app_pill.dot'),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _dotColor(dot!),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTokens.fontSans,
                fontSize: AppTokens.captionSize,
                height: AppTokens.captionLineHeight / AppTokens.captionSize,
                fontWeight: AppTokens.captionWeight,
                color: colors.foreground,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _AppPillColors _colorsFor(_AppPillVariant variant) {
    switch (variant) {
      case _AppPillVariant.primary:
        return _AppPillColors(
          background: AppTokens.primary.withValues(alpha: 0.18),
          foreground: AppTokens.primaryHover,
        );
      case _AppPillVariant.neutral:
        return const _AppPillColors(
          background: AppTokens.surface3,
          foreground: AppTokens.text2,
        );
      case _AppPillVariant.danger:
        return _AppPillColors(
          background: AppTokens.danger.withValues(alpha: 0.16),
          foreground: AppTokens.danger,
        );
      case _AppPillVariant.outline:
        return _AppPillColors(
          background: Colors.transparent,
          foreground: AppTokens.text2,
          border: Border.all(color: AppTokens.divider),
        );
    }
  }

  static Color _dotColor(AppPillDot dot) {
    switch (dot) {
      case AppPillDot.active:
        return AppTokens.accent;
      case AppPillDot.paused:
        return AppTokens.text2;
      case AppPillDot.danger:
        return AppTokens.danger;
    }
  }
}

class _AppPillColors {
  const _AppPillColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
}
