import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Tokens visuales canónicos del cliente.
///
/// Solo dark mode — el producto no tiene tema claro hoy. Los hex provienen
/// del design kit; cualquier divergencia del kit es un bug acá. Mantener
/// alfabético dentro de cada bloque temático para auditar diffs rápido.
class AppTokens {
  const AppTokens._();

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const Color bgBase = Color(0xFF0B141A);
  static const Color surface1 = Color(0xFF111B21);
  static const Color surface2 = Color(0xFF1F2C33);
  static const Color surface3 = Color(0xFF2A3942);

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF00A884);
  static const Color primaryHover = Color(0xFF06CF9C);
  static const Color accent = Color(0xFF25D366);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color text1 = Color(0xFFE9EDEF);
  static const Color text2 = Color(0xFF8696A0);
  static const Color textDisabled = Color(0xFF54656F);

  // ── Status & lines ──────────────────────────────────────────────────────
  static const Color divider = Color(0xFF222D34);
  static const Color danger = Color(0xFFF15C6D);
  static const Color warning = Color(0xFFFFB74D);
  static const Color success = primary;

  // ── Radii (px) ──────────────────────────────────────────────────────────
  static const double radiusPill = 999.0;
  static const double radiusCard = 20.0;
  static const double radiusButton = 14.0;
  static const double radiusField = 14.0;
  static const double radiusChip = 10.0;
  static const double radiusSm = 8.0;

  // ── Spacing (4pt grid) ──────────────────────────────────────────────────
  static const double sp1 = 4.0;
  static const double sp2 = 8.0;
  static const double sp3 = 12.0;
  static const double sp4 = 16.0;
  static const double sp5 = 20.0;
  static const double sp6 = 24.0;
  static const double sp7 = 32.0;
  static const double sp8 = 40.0;
  static const double sp9 = 56.0;

  static const double cardPadding = sp5;
  static const double cardGap = 14.0;

  // ── Typography ──────────────────────────────────────────────────────────
  static const String fontSans = 'DMSans';

  static const double displaySize = 28.0;
  static const double displayLineHeight = 34.0;
  static const FontWeight displayWeight = FontWeight.w700;

  static const double titleLSize = 22.0;
  static const double titleLLineHeight = 28.0;
  static const FontWeight titleLWeight = FontWeight.w600;

  static const double titleMSize = 18.0;
  static const double titleMLineHeight = 24.0;
  static const FontWeight titleMWeight = FontWeight.w600;

  static const double bodyLSize = 16.0;
  static const double bodyLLineHeight = 24.0;
  static const FontWeight bodyLWeight = FontWeight.w400;

  static const double bodyMSize = 14.0;
  static const double bodyMLineHeight = 20.0;
  static const FontWeight bodyMWeight = FontWeight.w400;

  static const double captionSize = 12.0;
  static const double captionLineHeight = 16.0;
  static const FontWeight captionWeight = FontWeight.w500;

  // ── Motion ──────────────────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 120);
  static const Duration durationBase = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 320);

  static const Cubic ease = Cubic(0.2, 0.0, 0.0, 1.0);
}
