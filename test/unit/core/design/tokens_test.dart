import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';

void main() {
  group('AppTokens — surfaces', () {
    test('bgBase es #0B141A (fondo de pantalla)', () {
      expect(AppTokens.bgBase, const Color(0xFF0B141A));
    });

    test('surface1 es #111B21 (app bar / sheets)', () {
      expect(AppTokens.surface1, const Color(0xFF111B21));
    });

    test('surface2 es #1F2C33 (cards default)', () {
      expect(AppTokens.surface2, const Color(0xFF1F2C33));
    });

    test('surface3 es #2A3942 (bloques elevados dentro de cards)', () {
      expect(AppTokens.surface3, const Color(0xFF2A3942));
    });
  });

  group('AppTokens — brand', () {
    test('primary es #00A884 (verde WhatsApp acción)', () {
      expect(AppTokens.primary, const Color(0xFF00A884));
    });

    test('primaryHover es #06CF9C', () {
      expect(AppTokens.primaryHover, const Color(0xFF06CF9C));
    });

    test('accent es #25D366 (badges y estados activos)', () {
      expect(AppTokens.accent, const Color(0xFF25D366));
    });
  });

  group('AppTokens — text', () {
    test('text1 es #E9EDEF (primario)', () {
      expect(AppTokens.text1, const Color(0xFFE9EDEF));
    });

    test('text2 es #8696A0 (secundario)', () {
      expect(AppTokens.text2, const Color(0xFF8696A0));
    });

    test('textDisabled es #54656F', () {
      expect(AppTokens.textDisabled, const Color(0xFF54656F));
    });
  });

  group('AppTokens — status', () {
    test('danger es #F15C6D', () {
      expect(AppTokens.danger, const Color(0xFFF15C6D));
    });

    test('warning es #FFB74D', () {
      expect(AppTokens.warning, const Color(0xFFFFB74D));
    });

    test('success es #00A884 (alias semántico de primary)', () {
      expect(AppTokens.success, AppTokens.primary);
    });

    test('divider es #222D34 (hairline)', () {
      expect(AppTokens.divider, const Color(0xFF222D34));
    });
  });

  group('AppTokens — radii (en px)', () {
    test('escala completa: pill/card/button/field/chip/sm', () {
      expect(AppTokens.radiusPill, 999.0);
      expect(AppTokens.radiusCard, 20.0);
      expect(AppTokens.radiusButton, 14.0);
      expect(AppTokens.radiusField, 14.0);
      expect(AppTokens.radiusChip, 10.0);
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
