import 'package:flutter/material.dart';

import '../tokens.dart';

enum AppTextActionTone { primary, neutral, danger }

/// Acción textual secundaria para enlaces, reintentos compactos y descartes.
/// Conserva un blanco táctil de 48 px sin adoptar el peso visual de un CTA.
class AppTextAction extends StatelessWidget {
  const AppTextAction({
    super.key,
    required this.label,
    this.tone = AppTextActionTone.primary,
    required this.onPressed,
  });

  final String label;
  final AppTextActionTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppTextActionTone.primary => AppTokens.primary,
      AppTextActionTone.neutral => AppTokens.text2,
      AppTextActionTone.danger => AppTokens.danger,
    };
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: color.withValues(alpha: 0.4),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
        textStyle: const TextStyle(
          fontFamily: AppTokens.fontSans,
          fontSize: AppTokens.bodyMSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}
