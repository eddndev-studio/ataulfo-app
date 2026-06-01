import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import 'wa_label_palette.dart';

/// Punto de color que representa el índice de paleta de una etiqueta WhatsApp.
/// Resuelve el índice a un color vía [WaLabelPalette] y lo pinta como un círculo
/// con un borde sutil para que destaque sobre el tema oscuro.
class WaLabelSwatch extends StatelessWidget {
  const WaLabelSwatch({super.key, required this.colorIndex, this.size = 24});

  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: WaLabelPalette.resolve(colorIndex),
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.divider),
      ),
    );
  }
}
