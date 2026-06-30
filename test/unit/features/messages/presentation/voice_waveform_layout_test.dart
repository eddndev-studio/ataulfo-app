import 'package:ataulfo/features/messages/presentation/widgets/live_waveform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometría del waveform en vivo de la grabación: barras de grosor/paso
/// CONSTANTE, ancladas a la derecha (la muestra más nueva entra por el borde
/// derecho) y deslizándose a la izquierda con `phase` — un carrusel, no un
/// re-layout que empuja y reescala conforme se acumulan muestras.
void main() {
  group('waveformBars', () {
    const barWidth = 3.0;
    const gap = 2.0;
    const pitch = barWidth + gap; // 5
    const width = 100.0;

    test('ancla la muestra más nueva al borde derecho (phase 0)', () {
      final bars = waveformBars(
        count: 10,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      expect(bars, isNotEmpty);
      final newest = bars.first; // k = 0
      expect(newest.sampleIndex, 9); // count - 1
      expect(newest.xCenter, closeTo(width - barWidth / 2, 1e-9)); // 98.5
    });

    test('grosor/paso constante: el espaciado NO depende de count', () {
      final few = waveformBars(
        count: 3,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      final many = waveformBars(
        count: 50,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      // La más nueva queda en el mismo lugar (derecha) con pocas o muchas.
      expect(few.first.xCenter, closeTo(many.first.xCenter, 1e-9));
      // Paso == pitch en ambos casos (no se comprime ni estira con count).
      expect(few[0].xCenter - few[1].xCenter, closeTo(pitch, 1e-9));
      expect(many[0].xCenter - many[1].xCenter, closeTo(pitch, 1e-9));
    });

    test('phase desliza todo el tren a la izquierda en fracción de pitch', () {
      final at0 = waveformBars(
        count: 20,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      final atHalf = waveformBars(
        count: 20,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0.5,
      );
      expect(
        atHalf.first.xCenter,
        closeTo(at0.first.xCenter - 0.5 * pitch, 1e-9),
      );
    });

    test('con pocas muestras sólo devuelve esas (llena desde la derecha)', () {
      final bars = waveformBars(
        count: 3,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      expect(bars.length, 3);
      expect(bars.map((b) => b.sampleIndex).toList(), <int>[2, 1, 0]);
    });

    test('culla las barras que ya salieron por la izquierda', () {
      // width 100, pitch 5 => ~20 caben; con 100 muestras NO devuelve 100.
      final bars = waveformBars(
        count: 100,
        width: width,
        barWidth: barWidth,
        gap: gap,
        phase: 0,
      );
      expect(bars.length, lessThan(100));
      for (final b in bars) {
        // Ninguna barra con su borde derecho fuera del lienzo por la izquierda.
        expect(b.xCenter + barWidth / 2, greaterThanOrEqualTo(0));
      }
    });

    test('vacío si no hay muestras o el ancho no es positivo', () {
      expect(
        waveformBars(
          count: 0,
          width: width,
          barWidth: barWidth,
          gap: gap,
          phase: 0,
        ),
        isEmpty,
      );
      expect(
        waveformBars(
          count: 10,
          width: 0,
          barWidth: barWidth,
          gap: gap,
          phase: 0,
        ),
        isEmpty,
      );
    });
  });
}
