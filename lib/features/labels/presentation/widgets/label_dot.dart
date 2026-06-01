import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';

/// Parsea el `color` hex de un Label interno (`#RRGGBB` o `#AARRGGBB`) a un
/// `Color`. Tolera mayúsculas/minúsculas y la ausencia del `#`. Un hex inválido
/// devuelve un color de fallback estable (no crashea): el wire debería traer
/// siempre un hex válido, pero la UI no debe romperse por drift.
Color parseLabelHex(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) {
    h = h.substring(1);
  }
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  } else if (h.length == 8) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(v);
  }
  return AppTokens.text2;
}

/// Punto de color de un Label interno (color hex, a diferencia del swatch de
/// paleta de una etiqueta WhatsApp). Círculo con borde sutil sobre el tema
/// oscuro.
class LabelDot extends StatelessWidget {
  const LabelDot({super.key, required this.hex, this.size = 16});

  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: parseLabelHex(hex),
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.divider),
      ),
    );
  }
}
