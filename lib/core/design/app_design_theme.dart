import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme dark canónico del design system de Ataúlfo.
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
      // Transparente a propósito: el fondo absoluto de la app es el glow
      // radial que pinta AppBackground detrás del navigator. Un scaffold
      // opaco lo taparía. canvasColor sí permanece sólido (bgBase) porque lo
      // consumen menús, dropdowns y drawers, que no deben transparentarse.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppTokens.bgBase,
      textTheme: textTheme,
      fontFamily: AppTokens.fontSans,
      dividerTheme: const DividerThemeData(
        color: AppTokens.divider,
        thickness: 1,
        space: 1,
      ),
      // El chrome (app bar, nav, FAB) va transparente sobre el glow: la barra
      // no pinta superficie ni proyecta sombra/tinte, y el contenido scrollea
      // por debajo dejando el glow fijo a la vista.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.text1,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTokens.primary,
        unselectedItemColor: AppTokens.text2,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: AppTokens.primary),
        unselectedIconTheme: IconThemeData(color: AppTokens.text2),
        selectedLabelTextStyle: TextStyle(color: AppTokens.primary),
        unselectedLabelTextStyle: TextStyle(color: AppTokens.text2),
      ),
      // El FAB es la acción cálida del shell: fill primary con primer plano
      // oscuro (onPrimary), coherente con AppButton.filled.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.primary,
        foregroundColor: AppTokens.onPrimary,
      ),
      // El glow es el fondo absoluto y fijo de la app; durante una transición
      // de ruta debe seguir viéndose. El builder por defecto de Android pinta
      // `colorScheme.surface` como scrim del tránsito, que tapaba el glow con
      // un gris en los frames de la animación. Con scrim transparente el glow
      // fijo (detrás del navigator) se ve durante toda la transición. iOS usa
      // su transición nativa, que no pinta scrim opaco.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: Colors.transparent,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
