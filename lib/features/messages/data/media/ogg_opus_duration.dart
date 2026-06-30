import 'dart:typed_data';

/// Calcula la duración (ms) de una nota de voz Opus-en-Ogg leyendo el
/// contenedor: la posición de granule del último page —en unidades de 48 kHz,
/// como manda Opus, independiente del sample rate de captura— menos el
/// `pre-skip` declarado en el `OpusHead` del primer page. Devuelve `null` si
/// los bytes no son un Ogg con `OpusHead` reconocible o si no se pudo derivar
/// una duración positiva.
///
/// just_audio/ExoPlayer no reporta de forma fiable la duración de las notas de
/// voz Opus/Ogg (ni las grabadas ni las recibidas), así que la barra de
/// progreso quedaba muerta. Calcularla del contenedor —que el cliente ya tiene
/// en memoria para reproducir desde disco— la revive en ambos sentidos sin
/// depender del transporte ni de un campo del wire, y sobrevive a reinicios.
int? oggOpusDurationMs(Uint8List b) {
  // Opus fija el granule en 48 kHz.
  const sampleRate = 48000;
  // -1 (0xFFFF…FF, que en un int de 64 bits con signo es -1): ningún paquete
  // termina en ese page, así que no marca un fin de stream.
  const noPacketEnd = -1;

  var offset = 0;
  var preSkip = 0;
  var sawOpusHead = false;
  var lastGranule = 0;

  while (offset + 27 <= b.length) {
    // Patrón de captura "OggS"; si no, no es (o dejó de ser) un page válido.
    if (b[offset] != 0x4F ||
        b[offset + 1] != 0x67 ||
        b[offset + 2] != 0x67 ||
        b[offset + 3] != 0x53) {
      break;
    }
    final granule = _u64le(b, offset + 6);
    final pageSegments = b[offset + 26];
    final segTable = offset + 27;
    if (segTable + pageSegments > b.length) break;
    var payloadLen = 0;
    for (var i = 0; i < pageSegments; i++) {
      payloadLen += b[segTable + i];
    }
    final payloadStart = segTable + pageSegments;
    if (payloadStart + payloadLen > b.length) break;

    if (granule != noPacketEnd) lastGranule = granule;

    if (!sawOpusHead) {
      if (payloadLen >= 12 &&
          b[payloadStart] == 0x4F && // "OpusHead"
          b[payloadStart + 1] == 0x70 &&
          b[payloadStart + 2] == 0x75 &&
          b[payloadStart + 3] == 0x73 &&
          b[payloadStart + 4] == 0x48 &&
          b[payloadStart + 5] == 0x65 &&
          b[payloadStart + 6] == 0x61 &&
          b[payloadStart + 7] == 0x64) {
        preSkip = b[payloadStart + 10] | (b[payloadStart + 11] << 8);
        sawOpusHead = true;
      } else {
        // El primer page de un Opus/Ogg DEBE traer OpusHead; si no, no es lo
        // que sabemos medir.
        return null;
      }
    }

    offset = payloadStart + payloadLen;
  }

  if (!sawOpusHead) return null;
  final samples = lastGranule - preSkip;
  if (samples <= 0) return null;
  return (samples * 1000) ~/ sampleRate;
}

int _u64le(Uint8List b, int o) {
  var v = 0;
  for (var i = 7; i >= 0; i--) {
    v = (v << 8) | b[o + i];
  }
  return v;
}
