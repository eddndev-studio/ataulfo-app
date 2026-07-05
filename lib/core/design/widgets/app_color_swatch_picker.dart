import 'package:flutter/material.dart';

import '../tokens.dart';

/// Una opción de un [AppColorSwatchPicker]: el círculo visible ([swatch],
/// típicamente un dot de 28px — `LabelDot`, `WaLabelSwatch` o un swatch
/// "sin color"), si está seleccionada y qué hace el tap. El [key] identifica
/// la opción para los tests del consumidor (`label_palette.3`,
/// `note_edit.color.none`, …).
class AppColorSwatchOption {
  const AppColorSwatchOption({
    required this.key,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final Key key;
  final Widget swatch;
  final bool selected;
  final VoidCallback onTap;
}

/// Rejilla de swatches de color del design system: la comparten los editores
/// que eligen un color de una paleta curada (notas, etiquetas internas,
/// etiquetas WhatsApp).
///
/// Cada opción reserva un objetivo táctil de 44x44 (el círculo visible mide
/// menos: sin el área extendida, acertar con el pulgar exige puntería) y el
/// seleccionado se marca con un anillo de marca alrededor del swatch. El
/// anillo reserva su grosor también sin selección (borde transparente) para
/// que elegir no mueva el layout. `enabled=false` bloquea todos los taps
/// (mutación en vuelo).
class AppColorSwatchPicker extends StatelessWidget {
  const AppColorSwatchPicker({
    super.key,
    required this.options,
    this.enabled = true,
  });

  final List<AppColorSwatchOption> options;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.sp3,
      runSpacing: AppTokens.sp3,
      children: <Widget>[
        for (final option in options)
          GestureDetector(
            key: option.key,
            // opaque: el tap cuenta en todo el cuadro de 44x44, no sólo en
            // los píxeles pintados del círculo.
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? option.onTap : null,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: option.selected
                          ? AppTokens.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: option.swatch,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
