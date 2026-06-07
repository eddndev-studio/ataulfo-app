import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

// ── Primitivas crudas del kit (Figma · colección Primitives) ──────────────
//
// Escalas de color puras. PRIVADAS a este archivo: nada fuera de [AppTokens]
// las referencia. Existen para que el mapeo semántico de abajo sea auditable
// 1:1 contra el kit (`gray/950`, `yellow/700`, …) y para que un cambio de
// rampa toque un solo lugar. Solo se declaran los escalones que un token
// semántico consume hoy; añadir más a medida que el kit los use.

class _Gray {
  const _Gray._();
  static const Color s100 = Color(0xFFE9EDEF);
  static const Color s400 = Color(0xFF8696A0);
  static const Color s500 = Color(0xFF323D43);
  static const Color s700 = Color(0xFF192228);
  static const Color s750 = Color(0xFF141B1F);
  static const Color s800 = Color(0xFF131A1F);
  static const Color s900 = Color(0xFF0A1014);
  static const Color s950 = Color(0xFF070C10);

  /// gray/800 al 60% de opacidad — fondos translúcidos (input, glass).
  static const Color s800a60 = Color(0x99131A1F);
}

class _Yellow {
  const _Yellow._();
  static const Color s500 = Color(0xFFECE500);
  static const Color s700 = Color(0xFFEDB900);
  static const Color s900 = Color(0xFFEB7500);

  /// yellow/700 al ~35% — glow de foco y sombra del FAB.
  static const Color s700a35 = Color(0x59EDB900);
}

class _Teal {
  const _Teal._();
  static const Color s500 = Color(0xFF00A884);
}

class _Green {
  const _Green._();
  static const Color s500 = Color(0xFF25D366);
}

class _Red {
  const _Red._();
  static const Color s400 = Color(0xFFF15C6D);
}

class _Orange {
  const _Orange._();
  static const Color s300 = Color(0xFFFFB74D);
}

/// Tokens visuales canónicos del cliente (Figma · colección Semantic).
///
/// Solo dark mode — el producto no tiene tema claro hoy. Cada token resuelve
/// contra una primitiva del kit; cualquier divergencia del kit es un bug acá.
/// Mantener alfabético dentro de cada bloque temático para auditar diffs
/// rápido.
class AppTokens {
  const AppTokens._();

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const Color bgBase = _Gray.s950; // base
  static const Color surface1 = _Gray.s900; // 1 — app bar / sheets
  static const Color surface2 = _Gray.s800; // 2 — cards default
  static const Color surface3 = _Gray.s700; // 3 — bloques elevados
  static const Color divider = _Gray.s750; // hairline

  /// Fondo translúcido de campos. `gray/800/60` del kit.
  static const Color input = _Gray.s800a60;

  /// Superficie glass (cards sobre fondos vivos). `gray/800/60` del kit —
  /// mismo valor que [input], distinto rol semántico.
  static const Color glass = _Gray.s800a60;

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = _Yellow.s700;
  static const Color primaryHover = _Yellow.s500;
  static const Color accent = _Yellow.s900;

  /// Texto/íconos sobre cualquier fill cálido (primary, accent, gradiente).
  /// `gray/950` del kit — el amarillo exige primer plano oscuro para contraste.
  static const Color onPrimary = _Gray.s950;

  /// Gradiente de marca (`surface/primary-g`): `primary` → `accent`. Lo usan
  /// los botones rellenos y las cards destacadas. Compuesto de los dos tokens
  /// de marca; la dirección topLeft→bottomRight sigue el flujo del home.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primary, accent],
  );

  /// Tinte del glow de foco (campos) y de la sombra del FAB. `primary` al ~35%.
  static const Color primaryGlow = _Yellow.s700a35;

  /// Fondo absoluto de la app: glow radial cálido anclado en el borde
  /// INFERIOR que se disuelve en [bgBase] hacia arriba. Compuesto de los tokens
  /// de marca (primary→accent) sobre el fondo base; las pantallas se montan
  /// encima con app bars transparentes. El centro va en el borde inferior y el
  /// radio es chico (~bottom 20% de la vista) para que el calor sea una franja
  /// baja y el cuerpo respire en oscuro.
  ///
  /// Va a intensidad plena: las paradas cálidas son la marca pura (primary→
  /// accent), no atenuadas. La última parada queda en [bgBase], así que el
  /// gradiente sigue siendo opaco de extremo a extremo (no necesita capa base
  /// extra). Es una capa de fondo: el contenido scrollea encima.
  static const RadialGradient backgroundGlow = RadialGradient(
    center: Alignment(0.0, 1.0),
    radius: 0.5,
    colors: <Color>[primary, accent, bgBase],
    stops: <double>[0.0, 0.45, 0.9],
  );

  // ── Section accents ───────────────────────────────────────────────────────
  /// Verde brillante que marca la superficie de **conversaciones/chat**: la
  /// distingue del amarillo de marca sin reemplazarlo. Uso *ligero* y por
  /// disciplina de consumo (como cualquier token): solo detalles de esa sección
  /// —tick de leído, barra de cita de respuesta, enlaces/acciones del hilo—, no
  /// fills ni chrome. Rol propio: NO es [success] (`teal/500`, otra primitiva,
  /// significa éxito), aunque ambos sean verdosos.
  static const Color chatAccent = _Green.s500;

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color text1 = _Gray.s100;
  static const Color text2 = _Gray.s400;
  static const Color textDisabled = _Gray.s500;

  // ── Status & lines ──────────────────────────────────────────────────────
  static const Color danger = _Red.s400;
  static const Color warning = _Orange.s300;

  /// `teal/500` — independiente de [primary] (el amarillo no comunica éxito).
  static const Color success = _Teal.s500;

  // ── Radii (px) ──────────────────────────────────────────────────────────
  static const double radiusPill = 999.0; // radius/full
  static const double radiusCard = 20.0; // radius/5
  static const double radiusButton = 999.0; // radius/full — pill
  static const double radiusField = 999.0; // radius/full — pill
  static const double radiusChip = 8.0; // radius/2
  static const double radiusSm = 8.0; // radius/2

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
