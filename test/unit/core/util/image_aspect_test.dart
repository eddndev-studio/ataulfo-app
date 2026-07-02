import 'dart:convert';
import 'dart:typed_data';

import 'package:ataulfo/core/util/image_aspect.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG 4×2 (RGBA) y 2×4, generados con encabezado IHDR estándar.
final _png4x2 = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR42mMIqDjxHxkzoAsAAFK1FHkNntrXAAAAAElFTkSuQmCC',
  ),
);
final _png2x4 = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAECAYAAACk7+45AAAAEUlEQVR42mMIqDjxH4QZcDMAZy8UeZKbYFMAAAAASUVORK5CYII=',
  ),
);
final _png1x1 = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  ),
);

void main() {
  group('imageDimensions', () {
    test('PNG lee ancho×alto del IHDR', () {
      expect(imageDimensions(_png4x2), (4, 2));
      expect(imageDimensions(_png2x4), (2, 4));
      expect(imageDimensions(_png1x1), (1, 1));
    });

    test('GIF lee ancho×alto little-endian', () {
      // 'GIF89a' + width=3 (03 00) + height=2 (02 00) + relleno mínimo.
      final gif = Uint8List.fromList(<int>[
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // GIF89a
        0x03, 0x00, 0x02, 0x00, // 3×2
        0x00, 0x00,
      ]);
      expect(imageDimensions(gif), (3, 2));
    });

    test('JPEG lee ancho×alto del marcador SOF0', () {
      // FFD8 (SOI) + FFC0 (SOF0) len=17 precision=8 alto=2 ancho=4 ...
      final jpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8,
        0xFF, 0xC0, 0x00, 0x11, 0x08, //
        0x00, 0x02, // alto = 2
        0x00, 0x04, // ancho = 4
        0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      ]);
      expect(imageDimensions(jpeg), (4, 2));
    });

    test('formato no reconocido o truncado ⇒ null', () {
      expect(imageDimensions(Uint8List.fromList(<int>[1, 2, 3])), isNull);
      expect(imageDimensions(Uint8List(0)), isNull);
    });

    test('JPEG tolera bytes de relleno 0xFF antes del marcador', () {
      // FFD8 (SOI) + FF FF (relleno) + FFC0 (SOF0) len=17 precision alto ancho
      final jpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8,
        0xFF, 0xFF, // relleno legal
        0xFF, 0xC0, 0x00, 0x11, 0x08, //
        0x00, 0x02, // alto = 2
        0x00, 0x04, // ancho = 4
        0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      ]);
      expect(imageDimensions(jpeg), (4, 2));
    });

    test('JPEG con EXIF Orientation=6 transpone ancho×alto', () {
      // SOI + APP1(EXIF, II, IFD0 con 1 entrada Orientation=6) + SOF0(H=2,W=4).
      // Orientation 6 ⇒ el motor rota 90°, así que la relación real es 2×4.
      final app1 = <int>[
        0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
        0x49, 0x49, 0x2A, 0x00, // TIFF little-endian + magic 0x2A
        0x08, 0x00, 0x00, 0x00, // offset del IFD0 = 8 (desde el TIFF header)
        0x01, 0x00, // 1 entrada
        0x12, 0x01, // tag 0x0112 (Orientation)
        0x03, 0x00, // tipo SHORT
        0x01, 0x00, 0x00, 0x00, // count 1
        0x06, 0x00, 0x00, 0x00, // valor 6
        0x00, 0x00, 0x00, 0x00, // next IFD = 0
      ];
      final len = app1.length + 2; // longitud incluye los 2 bytes de longitud
      final jpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8,
        0xFF, 0xE1, (len >> 8) & 0xFF, len & 0xFF, ...app1,
        0xFF, 0xC0, 0x00, 0x11, 0x08, //
        0x00, 0x02, // alto = 2
        0x00, 0x04, // ancho = 4
        0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
      ]);
      expect(imageDimensions(jpeg), (2, 4));
    });

    test('firma PNG pero primer chunk no es IHDR ⇒ null (no lee basura)', () {
      final fake = Uint8List(24);
      // Firma PNG válida.
      fake.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // Chunk type en 12..15 = "junk" (no "IHDR"); dims en 16/20 = basura.
      fake.setAll(12, <int>[0x6A, 0x75, 0x6E, 0x6B]);
      fake.setAll(16, <int>[0x04, 0x00, 0x00, 0x00]); // ancho enorme falso
      expect(imageDimensions(fake), isNull);
    });
  });

  group('imageAspectRatio', () {
    test('deriva la relación ancho/alto', () {
      expect(imageAspectRatio(_png4x2), closeTo(2.0, 1e-9));
      expect(imageAspectRatio(_png2x4), closeTo(0.5, 1e-9));
      expect(imageAspectRatio(_png1x1), closeTo(1.0, 1e-9));
    });

    test('formato no reconocido ⇒ null', () {
      expect(imageAspectRatio(Uint8List.fromList(<int>[9, 9, 9])), isNull);
    });
  });
}
