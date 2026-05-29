import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme dark canónico del design system de Agentic.
///
/// Solo dark — el producto no tiene tema claro hoy. Construido sobre
/// [AppTokens]; cualquier color/tipografía aquí debe derivar de un token,
/// no aparecer como literal. Coexiste con `AppTheme` legado mientras se
/// migran páginas; el cableado al `MaterialApp.theme` se hace en su
/// propio slice.
class AppDesignTheme {
  const AppDesignTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppTokens.primary,
      // El amarillo de marca exige primer plano oscuro: texto/íconos sobre
      // cualquier fill cálido (primary o accent) usan onPrimary (gray/950).
      onPrimary: AppTokens.onPrimary,
      secondary: AppTokens.accent,
      onSecondary: AppTokens.onPrimary,
      surface: AppTokens.surface2,
      onSurface: AppTokens.text1,
      onSurfaceVariant: AppTokens.text2,
      error: AppTokens.danger,
      onError: Colors.white,
      outline: AppTokens.divider,
    );

    final textTheme = _textTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppTokens.bgBase,
      canvasColor: AppTokens.bgBase,
      textTheme: textTheme,
      fontFamily: AppTokens.fontSans,
      dividerTheme: const DividerThemeData(
        color: AppTokens.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme() {
    TextStyle base({
      required double size,
      required double height,
      required FontWeight weight,
      Color color = AppTokens.text1,
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: AppTokens.fontSans,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: base(
        size: AppTokens.displaySize,
        height: AppTokens.displayLineHeight,
        weight: AppTokens.displayWeight,
        letterSpacing: -0.28,
      ),
      titleLarge: base(
        size: AppTokens.titleLSize,
        height: AppTokens.titleLLineHeight,
        weight: AppTokens.titleLWeight,
        letterSpacing: -0.11,
      ),
      titleMedium: base(
        size: AppTokens.titleMSize,
        height: AppTokens.titleMLineHeight,
        weight: AppTokens.titleMWeight,
      ),
      bodyLarge: base(
        size: AppTokens.bodyLSize,
        height: AppTokens.bodyLLineHeight,
        weight: AppTokens.bodyLWeight,
      ),
      bodyMedium: base(
        size: AppTokens.bodyMSize,
        height: AppTokens.bodyMLineHeight,
        weight: AppTokens.bodyMWeight,
      ),
      labelSmall: base(
        size: AppTokens.captionSize,
        height: AppTokens.captionLineHeight,
        weight: AppTokens.captionWeight,
        color: AppTokens.text2,
        letterSpacing: 0.12,
      ),
    );
  }
}
