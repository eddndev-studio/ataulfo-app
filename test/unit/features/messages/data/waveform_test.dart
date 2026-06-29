import 'package:ataulfo/features/messages/data/media/waveform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vacío ⇒ vacío', () {
    expect(downsampleWaveform(const <int>[], 64), isEmpty);
    expect(downsampleWaveform(const <int>[1, 2, 3], 0), isEmpty);
  });

  test('longitud igual a buckets se devuelve clampada', () {
    final out = downsampleWaveform(const <int>[0, 50, 100, 200, -5], 5);
    expect(out, <int>[0, 50, 100, 100, 0]);
  });

  test('más muestras que buckets promedia por grupo', () {
    final out = downsampleWaveform(const <int>[10, 20, 30, 40], 2);
    // [10,20] → 15 ; [30,40] → 35
    expect(out, <int>[15, 35]);
  });

  test(
    'menos muestras que buckets interpola hacia arriba a la longitud pedida',
    () {
      final out = downsampleWaveform(const <int>[0, 100], 3);
      // extremos preservados, medio interpolado
      expect(out.length, 3);
      expect(out.first, 0);
      expect(out.last, 100);
      expect(out[1], inInclusiveRange(40, 60));
    },
  );

  test('downsample a 64 desde muchas muestras da exactamente 64', () {
    final many = List<int>.generate(500, (i) => i % 101);
    final out = downsampleWaveform(many, kWaveformSamples);
    expect(out.length, 64);
    expect(out.every((v) => v >= 0 && v <= 100), isTrue);
  });
}
