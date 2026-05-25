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

    test('scaffoldBackgroundColor = AppTokens.bgBase', () {
      expect(theme.scaffoldBackgroundColor, AppTokens.bgBase);
    });

    test('canvasColor = AppTokens.bgBase', () {
      expect(theme.canvasColor, AppTokens.bgBase);
    });
  });

  group('AppDesignTheme.dark — ColorScheme', () {
    final scheme = AppDesignTheme.dark().colorScheme;

    test('primary = AppTokens.primary', () {
      expect(scheme.primary, AppTokens.primary);
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
