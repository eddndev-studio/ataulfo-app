/// Cantidad de muestras del waveform de una nota de voz (convención de
/// WhatsApp: 64 valores 0-100).
const int kWaveformSamples = 64;

/// Reduce las muestras de amplitud crudas (0-100, capturadas en vivo durante
/// la grabación) a exactamente [buckets] muestras para el waveform nativo de
/// la nota de voz.
///
/// Con más muestras que buckets, promedia por grupo (downsample); con menos,
/// interpola linealmente hacia arriba para no dejar el waveform corto en notas
/// muy breves. Vacío ⇒ vacío. Cada salida queda clampada a 0-100.
List<int> downsampleWaveform(
  List<int> samples, [
  int buckets = kWaveformSamples,
]) {
  if (samples.isEmpty || buckets <= 0) return const <int>[];
  if (samples.length == buckets) {
    return samples.map(_clamp).toList(growable: false);
  }
  final out = List<int>.filled(buckets, 0);
  if (samples.length > buckets) {
    for (var i = 0; i < buckets; i++) {
      final start = (i * samples.length) ~/ buckets;
      final endRaw = ((i + 1) * samples.length) ~/ buckets;
      final end = endRaw <= start ? start + 1 : endRaw;
      var sum = 0;
      var n = 0;
      for (var j = start; j < end && j < samples.length; j++) {
        sum += samples[j];
        n++;
      }
      out[i] = n == 0 ? 0 : _clamp((sum / n).round());
    }
  } else if (buckets == 1) {
    out[0] = _clamp(samples.first);
  } else {
    final last = samples.length - 1;
    for (var i = 0; i < buckets; i++) {
      final pos = i * last / (buckets - 1);
      final lo = pos.floor();
      final hi = pos.ceil();
      if (lo == hi) {
        out[i] = _clamp(samples[lo]);
      } else {
        final frac = pos - lo;
        out[i] = _clamp(
          (samples[lo] * (1 - frac) + samples[hi] * frac).round(),
        );
      }
    }
  }
  return out;
}

int _clamp(int v) => v < 0 ? 0 : (v > 100 ? 100 : v);
