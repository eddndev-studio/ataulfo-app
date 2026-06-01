import 'package:flutter/painting.dart';

/// Resolución cliente del **índice de paleta** de una etiqueta WhatsApp a un
/// color visible. El protocolo de WhatsApp transmite la etiqueta con un `color`
/// entero (índice de una paleta predefinida) — no un hex; el cliente decide el
/// swatch. whatsmeow/el backend solo acarrean el índice.
///
/// Esta paleta es una aproximación de la de WhatsApp (vibrante, opaca, legible
/// sobre el tema oscuro). LIMITACIÓN NOMBRADA: la paridad de hex exacta con la
/// app de WhatsApp queda diferida; lo que importa para las automatizaciones es
/// el índice (que sí viaja fiel), no el tono mostrado.
///
/// `resolve` envuelve por módulo, así un índice fuera de rango (o negativo)
/// siempre rinde un color estable sin crashear: el índice 0 es legítimo.
class WaLabelPalette {
  const WaLabelPalette._();

  static const List<Color> colors = <Color>[
    Color(0xFFFF6B6B), // rojo coral
    Color(0xFFFF922B), // naranja
    Color(0xFFFFD43B), // ámbar
    Color(0xFFC0EB75), // lima
    Color(0xFF51CF66), // verde
    Color(0xFF20C997), // teal
    Color(0xFF22B8CF), // cian
    Color(0xFF4DABF7), // azul cielo
    Color(0xFF4263EB), // azul
    Color(0xFF7048E8), // índigo
    Color(0xFF9775FA), // violeta
    Color(0xFFDA77F2), // orquídea
    Color(0xFFF783AC), // rosa
    Color(0xFFFF8787), // salmón
    Color(0xFFFFA94D), // mandarina
    Color(0xFF94D82D), // verde lima
    Color(0xFF38D9A9), // menta
    Color(0xFF3BC9DB), // turquesa
    Color(0xFF748FFC), // periwinkle
    Color(0xFFB197FC), // lavanda
  ];

  /// Resuelve un índice de paleta a su color. Envuelve por módulo (índice
  /// negativo incluido) para tolerar cualquier valor del wire sin crashear.
  static Color resolve(int index) {
    final n = colors.length;
    final i = ((index % n) + n) % n;
    return colors[i];
  }
}
