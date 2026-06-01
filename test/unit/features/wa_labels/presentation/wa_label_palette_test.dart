import 'package:ataulfo/features/wa_labels/presentation/widgets/wa_label_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabelPalette', () {
    test('tiene una paleta no vacía de colores opacos', () {
      expect(WaLabelPalette.colors, isNotEmpty);
      for (final c in WaLabelPalette.colors) {
        expect(c.a, 1.0); // swatches opacos
      }
    });

    test('resolve(0) es válido (0 es un índice de paleta legítimo)', () {
      expect(WaLabelPalette.resolve(0), WaLabelPalette.colors.first);
    });

    test('resolve mapea cada índice a su color', () {
      for (var i = 0; i < WaLabelPalette.colors.length; i++) {
        expect(WaLabelPalette.resolve(i), WaLabelPalette.colors[i]);
      }
    });

    test('índice fuera de rango envuelve por módulo (nunca crashea)', () {
      final n = WaLabelPalette.colors.length;
      expect(WaLabelPalette.resolve(n), WaLabelPalette.colors[0]);
      expect(WaLabelPalette.resolve(n + 3), WaLabelPalette.colors[3 % n]);
    });

    test('índice negativo también resuelve a un color estable', () {
      final c = WaLabelPalette.resolve(-1);
      expect(WaLabelPalette.colors, contains(c));
    });
  });
}
