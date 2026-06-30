import 'dart:typed_data';

import 'package:ataulfo/features/messages/data/media/ogg_opus_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bytes little-endian de un uint64 (posición de granule del page Ogg).
List<int> _u64le(int v) => List<int>.generate(8, (i) => (v >> (8 * i)) & 0xFF);

/// Un page Ogg sintético: cabecera de 27 bytes + tabla de lacing + payload.
/// El parser ignora el CRC, así que va en cero.
Uint8List _page({
  required int granule,
  required int headerType,
  required List<int> payload,
  int serial = 1,
  int seq = 0,
}) {
  final segs = <int>[];
  var rem = payload.length;
  while (rem >= 255) {
    segs.add(255);
    rem -= 255;
  }
  segs.add(rem);
  return Uint8List.fromList(<int>[
    0x4F, 0x67, 0x67, 0x53, // "OggS"
    0, // versión
    headerType,
    ..._u64le(granule),
    serial & 0xFF, (serial >> 8) & 0xFF, (serial >> 16) & 0xFF,
    (serial >> 24) & 0xFF,
    seq & 0xFF, (seq >> 8) & 0xFF, (seq >> 16) & 0xFF, (seq >> 24) & 0xFF,
    0, 0, 0, 0, // CRC (el parser lo ignora)
    segs.length,
    ...segs,
    ...payload,
  ]);
}

/// Payload de un page OpusHead con [preSkip] declarado.
List<int> _opusHead(int preSkip) => <int>[
  0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
  1, // versión
  1, // canales
  preSkip & 0xFF, (preSkip >> 8) & 0xFF,
  0x80, 0x3E, 0, 0, // input sample rate 16000 (informativo)
  0, 0, // output gain
  0, // channel mapping family
];

void main() {
  group('oggOpusDurationMs', () {
    const preSkip = 312;
    const sampleRate = 48000; // Opus: granule siempre en 48 kHz

    test('clip de ~3s: granule final - preSkip / 48kHz', () {
      const lastGranule = preSkip + 3 * sampleRate; // 3.000 s
      final bytes = Uint8List.fromList(<int>[
        ..._page(granule: 0, headerType: 0x02, payload: _opusHead(preSkip)),
        ..._page(
          granule: lastGranule,
          headerType: 0x04, // EOS
          payload: <int>[1, 2, 3, 4, 5],
        ),
      ]);
      expect(oggOpusDurationMs(bytes), 3000);
    });

    test('ignora pages con granule -1 (paquete continuado)', () {
      const lastGranule = preSkip + 2 * sampleRate; // 2.000 s
      final bytes = Uint8List.fromList(<int>[
        ..._page(granule: 0, headerType: 0x02, payload: _opusHead(preSkip)),
        // page intermedio sin fin de paquete: granule = -1 (0xFFFF..FF)
        ..._page(granule: -1, headerType: 0x00, payload: <int>[9, 9, 9]),
        ..._page(granule: lastGranule, headerType: 0x04, payload: <int>[1, 2]),
      ]);
      expect(oggOpusDurationMs(bytes), 2000);
    });

    test('null si no es Ogg', () {
      expect(
        oggOpusDurationMs(Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8])),
        isNull,
      );
    });

    test('null si es Ogg pero el primer page no es OpusHead', () {
      final bytes = _page(
        granule: 48000,
        headerType: 0x02,
        payload: <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      );
      expect(oggOpusDurationMs(bytes), isNull);
    });

    test('null con bytes vacíos', () {
      expect(oggOpusDurationMs(Uint8List(0)), isNull);
    });
  });
}
