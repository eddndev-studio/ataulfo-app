import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';

void main() {
  group('AppTokens — surfaces', () {
    test('bgBase es #070C10 (gray/950, fondo de pantalla)', () {
      expect(AppTokens.bgBase, const Color(0xFF070C10));
    });

    test('surface1 es #0A1014 (gray/900, app bar / sheets)', () {
      expect(AppTokens.surface1, const Color(0xFF0A1014));
    });

    test('surface2 es #131A1F (gray/800, cards default)', () {
      expect(AppTokens.surface2, const Color(0xFF131A1F));
    });

    test('surface3 es #192228 (gray/700, bloques elevados)', () {
      expect(AppTokens.surface3, const Color(0xFF192228));
    });

    test('divider es #141B1F (gray/750, hairline)', () {
      expect(AppTokens.divider, const Color(0xFF141B1F));
    });

    test('input es gray/800 al 60% (#131A1F @ 0x99)', () {
      expect(AppTokens.input, const Color(0x99131A1F));
    });

    test('glass es gray/800 al 60% — mismo valor que input', () {
      expect(AppTokens.glass, const Color(0x99131A1F));
      expect(AppTokens.glass, AppTokens.input);
    });
  });

  group('AppTokens — brand', () {
    test('primary es #EDB900 (yellow/700, acción primaria)', () {
      expect(AppTokens.primary, const Color(0xFFEDB900));
    });

    test('primaryHover es #ECE500 (yellow/500)', () {
      expect(AppTokens.primaryHover, const Color(0xFFECE500));
    });

    test('accent es #EB7500 (yellow/900, naranja de marca)', () {
      expect(AppTokens.accent, const Color(0xFFEB7500));
    });

    test('onPrimary es #070C10 (gray/950, texto sobre fills cálidos)', () {
      expect(AppTokens.onPrimary, const Color(0xFF070C10));
    });

    test('brandGradient va de primary a accent (surface/primary-g)', () {
      const g = AppTokens.brandGradient;
      expect(g.colors, <Color>[AppTokens.primary, AppTokens.accent]);
    });

    test('primaryGlow es primary tintado para el glow de foco/FAB', () {
      // ~35% de alpha sobre primary (#EDB900).
      expect(AppTokens.primaryGlow, const Color(0x59EDB900));
    });

    test('backgroundGlow es radial con la marca atenuada ~35% sobre bgBase', () {
      // El glow es sutil: cada parada cálida se mezcla solo ~35% hacia la
      // marca desde bgBase (equivalente a pintarla a ~35% de opacidad sobre
      // la base), y la última parada queda en bgBase puro.
      final g = AppTokens.backgroundGlow;
      expect(g.colors, <Color>[
        Color.lerp(AppTokens.bgBase, AppTokens.primary, 0.35)!,
        Color.lerp(AppTokens.bgBase, AppTokens.accent, 0.35)!,
        AppTokens.bgBase,
      ]);
    });
  });

  group('AppTokens — text', () {
    test('text1 es #E9EDEF (gray/100, primario)', () {
      expect(AppTokens.text1, const Color(0xFFE9EDEF));
    });

    test('text2 es #8696A0 (gray/400, secundario)', () {
      expect(AppTokens.text2, const Color(0xFF8696A0));
    });

    test('textDisabled es #323D43 (gray/500)', () {
      expect(AppTokens.textDisabled, const Color(0xFF323D43));
    });
  });

  group('AppTokens — status', () {
    test('danger es #F15C6D (red/400)', () {
      expect(AppTokens.danger, const Color(0xFFF15C6D));
    });

    test('warning es #FFB74D (orange/300)', () {
      expect(AppTokens.warning, const Color(0xFFFFB74D));
    });

    test('success es #00A884 (teal/500, ya desacoplado de primary)', () {
      expect(AppTokens.success, const Color(0xFF00A884));
      expect(AppTokens.success, isNot(AppTokens.primary));
    });
  });

  group('AppTokens — radii (en px)', () {
    test('button y field son pill (full=999); chip/sm=8; card=20', () {
      expect(AppTokens.radiusPill, 999.0);
      expect(AppTokens.radiusCard, 20.0);
      expect(AppTokens.radiusButton, 999.0);
      expect(AppTokens.radiusField, 999.0);
      expect(AppTokens.radiusChip, 8.0);
      expect(AppTokens.radiusSm, 8.0);
    });
  });

  group('AppTokens — spacing (4pt grid)', () {
    test('escala 1..9 en múltiplos de 4', () {
      expect(AppTokens.sp1, 4.0);
      expect(AppTokens.sp2, 8.0);
      expect(AppTokens.sp3, 12.0);
      expect(AppTokens.sp4, 16.0);
      expect(AppTokens.sp5, 20.0);
      expect(AppTokens.sp6, 24.0);
      expect(AppTokens.sp7, 32.0);
      expect(AppTokens.sp8, 40.0);
      expect(AppTokens.sp9, 56.0);
    });

    test('cardPadding alias semántico de sp5', () {
      expect(AppTokens.cardPadding, AppTokens.sp5);
    });

    test('cardGap entre tarjetas apiladas', () {
      expect(AppTokens.cardGap, 14.0);
    });
  });

  group('AppTokens — type', () {
    test('fontSans es DMSans', () {
      expect(AppTokens.fontSans, 'DMSans');
    });

    test('display: 28/34 weight 700', () {
      expect(AppTokens.displaySize, 28.0);
      expect(AppTokens.displayLineHeight, 34.0);
      expect(AppTokens.displayWeight, FontWeight.w700);
    });

    test('titleL: 22/28 weight 600', () {
      expect(AppTokens.titleLSize, 22.0);
      expect(AppTokens.titleLLineHeight, 28.0);
      expect(AppTokens.titleLWeight, FontWeight.w600);
    });

    test('titleM: 18/24 weight 600', () {
      expect(AppTokens.titleMSize, 18.0);
      expect(AppTokens.titleMLineHeight, 24.0);
      expect(AppTokens.titleMWeight, FontWeight.w600);
    });

    test('bodyL: 16/24 weight 400', () {
      expect(AppTokens.bodyLSize, 16.0);
      expect(AppTokens.bodyLLineHeight, 24.0);
      expect(AppTokens.bodyLWeight, FontWeight.w400);
    });

    test('bodyM: 14/20 weight 400', () {
      expect(AppTokens.bodyMSize, 14.0);
      expect(AppTokens.bodyMLineHeight, 20.0);
      expect(AppTokens.bodyMWeight, FontWeight.w400);
    });

    test('caption: 12/16 weight 500', () {
      expect(AppTokens.captionSize, 12.0);
      expect(AppTokens.captionLineHeight, 16.0);
      expect(AppTokens.captionWeight, FontWeight.w500);
    });
  });

  group('AppTokens — motion', () {
    test('durations base/fast/slow', () {
      expect(AppTokens.durationFast, const Duration(milliseconds: 120));
      expect(AppTokens.durationBase, const Duration(milliseconds: 200));
      expect(AppTokens.durationSlow, const Duration(milliseconds: 320));
    });

    test('ease es Cubic(0.2, 0, 0, 1)', () {
      expect(AppTokens.ease, const Cubic(0.2, 0.0, 0.0, 1.0));
    });
  });
}
