import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';

void main() {
  group('AppDesignTheme.dark — foundations', () {
    final theme = AppDesignTheme.dark();

    test('useMaterial3 = true', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('brightness = dark (es dark-only)', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffoldBackgroundColor = transparent (deja ver el glow de fondo)', () {
      // El fondo absoluto de la app es el glow radial pintado por
      // AppBackground; el scaffold debe ser transparente para no taparlo.
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
    });

    test('canvasColor = AppTokens.bgBase (menús/popovers opacos)', () {
      // canvasColor sí permanece sólido: lo consumen menús, dropdowns y
      // drawers, que NO deben transparentarse sobre el glow.
      expect(theme.canvasColor, AppTokens.bgBase);
    });
  });

  group('AppDesignTheme.dark — chrome transparente sobre el glow', () {
    final theme = AppDesignTheme.dark();

    test('appBarTheme transparente y sin elevación', () {
      final appBar = theme.appBarTheme;
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);
      expect(appBar.scrolledUnderElevation, 0);
      // Sin tinte de superficie M3 al hacer scroll bajo la barra.
      expect(appBar.surfaceTintColor, Colors.transparent);
      // El primer plano (título, íconos) en text1 sobre el glow.
      expect(appBar.foregroundColor, AppTokens.text1);
    });

    test('bottomNavigationBarTheme transparente, seleccionado en primary', () {
      final nav = theme.bottomNavigationBarTheme;
      expect(nav.backgroundColor, Colors.transparent);
      expect(nav.elevation, 0);
      expect(nav.selectedItemColor, AppTokens.primary);
      expect(nav.unselectedItemColor, AppTokens.text2);
    });

    test('navigationRailTheme transparente, seleccionado en primary', () {
      final rail = theme.navigationRailTheme;
      expect(rail.backgroundColor, Colors.transparent);
      expect(rail.selectedIconTheme?.color, AppTokens.primary);
      expect(rail.unselectedIconTheme?.color, AppTokens.text2);
    });

    test('floatingActionButtonTheme en colores de marca', () {
      final fab = theme.floatingActionButtonTheme;
      // El FAB es la acción cálida: fill primary con primer plano oscuro.
      expect(fab.backgroundColor, AppTokens.primary);
      expect(fab.foregroundColor, AppTokens.onPrimary);
    });

    test('pageTransitionsTheme: Android sin scrim opaco (glow visible en '
        'la transición de ruta)', () {
      // El builder por defecto pinta colorScheme.surface como fondo del
      // tránsito, lo que tapaba el glow con un gris durante la animación. Con
      // scrim transparente, el glow fijo de fondo se ve durante la transición.
      final builder = theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(builder, isA<FadeForwardsPageTransitionsBuilder>());
      expect(
        (builder! as FadeForwardsPageTransitionsBuilder).backgroundColor,
        Colors.transparent,
      );
    });
  });

  group('AppDesignTheme.dark — ColorScheme', () {
    final scheme = AppDesignTheme.dark().colorScheme;

    test('primary = AppTokens.primary', () {
      expect(scheme.primary, AppTokens.primary);
    });

    test('onPrimary = AppTokens.onPrimary (texto oscuro sobre amarillo)', () {
      expect(scheme.onPrimary, AppTokens.onPrimary);
    });

    test('secondary = AppTokens.accent', () {
      expect(scheme.secondary, AppTokens.accent);
    });

    test('onSecondary = AppTokens.onPrimary (texto oscuro sobre naranja)', () {
      expect(scheme.onSecondary, AppTokens.onPrimary);
    });

    test('surface = AppTokens.surface2 (cards default)', () {
      expect(scheme.surface, AppTokens.surface2);
    });

    test('onSurface = AppTokens.text1', () {
      expect(scheme.onSurface, AppTokens.text1);
    });

    test('onSurfaceVariant = AppTokens.text2 (captions)', () {
      expect(scheme.onSurfaceVariant, AppTokens.text2);
    });

    test('error = AppTokens.danger', () {
      expect(scheme.error, AppTokens.danger);
    });

    test('outline = AppTokens.divider', () {
      expect(scheme.outline, AppTokens.divider);
    });
  });

  group('AppDesignTheme.dark — TextTheme (DM Sans)', () {
    final textTheme = AppDesignTheme.dark().textTheme;

    test('displayLarge usa DMSans size 28 weight 700', () {
      final s = textTheme.displayLarge!;
      expect(s.fontFamily, AppTokens.fontSans);
      expect(s.fontSize, AppTokens.displaySize);
      expect(s.fontWeight, AppTokens.displayWeight);
      expect(s.color, AppTokens.text1);
    });

    test('titleLarge usa size 22 weight 600', () {
      final s = textTheme.titleLarge!;
      expect(s.fontSize, AppTokens.titleLSize);
      expect(s.fontWeight, AppTokens.titleLWeight);
    });

    test('titleMedium usa size 18 weight 600', () {
      final s = textTheme.titleMedium!;
      expect(s.fontSize, AppTokens.titleMSize);
      expect(s.fontWeight, AppTokens.titleMWeight);
    });

    test('bodyLarge usa size 16 weight 400', () {
      final s = textTheme.bodyLarge!;
      expect(s.fontSize, AppTokens.bodyLSize);
      expect(s.fontWeight, AppTokens.bodyLWeight);
    });

    test('bodyMedium usa size 14 weight 400', () {
      final s = textTheme.bodyMedium!;
      expect(s.fontSize, AppTokens.bodyMSize);
      expect(s.fontWeight, AppTokens.bodyMWeight);
    });

    test('labelSmall (caption) usa size 12 weight 500 color text2', () {
      final s = textTheme.labelSmall!;
      expect(s.fontSize, AppTokens.captionSize);
      expect(s.fontWeight, AppTokens.captionWeight);
      expect(s.color, AppTokens.text2);
    });
  });
}
