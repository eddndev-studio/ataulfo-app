import 'dart:typed_data';

/// Relación de aspecto (ancho/alto) leída del ENCABEZADO de los bytes de una
/// imagen, sin decodificarla. Es síncrono a propósito: pintar una foto a su
/// forma real exige conocer la relación en el primer layout (en un `ListView`
/// el tamaño intrínseco del `Image` aún no está listo), y un decode del motor
/// es asíncrono y no resuelve durante el layout.
///
/// Cubre los formatos que el canal entrega como foto: PNG, JPEG y GIF. Un
/// formato no reconocido (p. ej. WebP) o un encabezado truncado ⇒ `null`, y la
/// vista cae a una caja cuadrada estable.
double? imageAspectRatio(Uint8List b) {
  final size = imageDimensions(b);
  if (size == null) return null;
  final (w, h) = size;
  return h > 0 ? w / h : null;
}

/// Dimensiones `(ancho, alto)` en píxeles leídas del encabezado, o `null` si el
/// formato no se reconoce o los bytes están truncados.
(int, int)? imageDimensions(Uint8List b) {
  return _png(b) ?? _gif(b) ?? _jpeg(b);
}

/// PNG: firma de 8 bytes + primer chunk que DEBE ser IHDR (tag en 12..15) con
/// ancho/alto (uint32 big-endian) en los offsets 16 y 20. Se valida el tag para
/// no leer basura de un archivo corrupto con firma PNG pero otro primer chunk.
(int, int)? _png(Uint8List b) {
  if (b.length < 24) return null;
  if (b[0] != 0x89 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) return null;
  // "IHDR"
  if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) {
    return null;
  }
  final w = _u32be(b, 16);
  final h = _u32be(b, 20);
  return (w > 0 && h > 0) ? (w, h) : null;
}

/// GIF: 'GIF87a'/'GIF89a' + ancho/alto (uint16 little-endian) en los offsets 6
/// y 8.
(int, int)? _gif(Uint8List b) {
  if (b.length < 10) return null;
  if (b[0] != 0x47 || b[1] != 0x49 || b[2] != 0x46) return null; // 'GIF'
  final w = b[6] | (b[7] << 8);
  final h = b[8] | (b[9] << 8);
  return (w > 0 && h > 0) ? (w, h) : null;
}

/// JPEG: 0xFFD8 + segmentos. El marcador SOF (0xC0..0xCF, salvo los no-frame
/// C4/C8/CC) lleva alto y ancho (uint16 big-endian) tras marcador+longitud+
/// precisión. Se toleran los bytes de relleno 0xFF antes de un marcador (JPEG
/// B.1.1.2) y se lee la Orientation EXIF (APP1): si rota 90° (5..8), el motor
/// pinta la imagen transpuesta, así que devolvemos ancho/alto intercambiados
/// para que la relación de aspecto coincida con lo que se ve.
(int, int)? _jpeg(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var i = 2;
  var orientation = 1;
  while (i + 3 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    // Colapsa una posible corrida de bytes de relleno 0xFF hasta el marcador.
    var m = i + 1;
    while (m < b.length && b[m] == 0xFF) {
      m++;
    }
    if (m >= b.length) break;
    final marker = b[m];
    // Marcadores sin campo de longitud (SOI/EOI, RSTn, TEM, relleno 0x00).
    if (marker == 0xD8 ||
        marker == 0xD9 ||
        marker == 0x01 ||
        marker == 0x00 ||
        (marker >= 0xD0 && marker <= 0xD7)) {
      i = m + 1;
      continue;
    }
    final lenIdx = m + 1;
    if (lenIdx + 1 >= b.length) break;
    final len = (b[lenIdx] << 8) | b[lenIdx + 1];
    if (len < 2) return null; // longitud malformada
    final payload = lenIdx + 2;
    if (marker == 0xE1) {
      final end = (payload + len - 2) <= b.length
          ? payload + len - 2
          : b.length;
      final o = _exifOrientation(b, payload, end);
      if (o != null) orientation = o;
    }
    final isSof =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isSof) {
      if (payload + 4 >= b.length) return null;
      // Payload SOF: precisión(1) + alto(2) + ancho(2).
      final h = (b[payload + 1] << 8) | b[payload + 2];
      final w = (b[payload + 3] << 8) | b[payload + 4];
      if (w <= 0 || h <= 0) return null;
      final rotated = orientation >= 5 && orientation <= 8;
      return rotated ? (h, w) : (w, h);
    }
    i = lenIdx + len; // siguiente marcador
  }
  return null;
}

/// Lee el valor de la etiqueta Orientation (0x0112) del bloque EXIF de un APP1
/// (`[start, end)`), o `null` si no está / no es EXIF. Sólo lo suficiente para
/// decidir si el motor rotará la imagen 90°.
int? _exifOrientation(Uint8List b, int start, int end) {
  if (end - start < 14) return null;
  // "Exif\0\0"
  if (b[start] != 0x45 ||
      b[start + 1] != 0x78 ||
      b[start + 2] != 0x69 ||
      b[start + 3] != 0x66 ||
      b[start + 4] != 0x00 ||
      b[start + 5] != 0x00) {
    return null;
  }
  final tiff = start + 6;
  final le = b[tiff] == 0x49 && b[tiff + 1] == 0x49; // 'II'
  final be = b[tiff] == 0x4D && b[tiff + 1] == 0x4D; // 'MM'
  if (!le && !be) return null;
  int u16(int o) => le ? b[o] | (b[o + 1] << 8) : (b[o] << 8) | b[o + 1];
  int u32(int o) => le
      ? b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)
      : (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  if (u16(tiff + 2) != 0x2A) return null; // magic TIFF
  final ifd0 = tiff + u32(tiff + 4);
  if (ifd0 < tiff || ifd0 + 2 > end) return null;
  final count = u16(ifd0);
  var entry = ifd0 + 2;
  for (var k = 0; k < count; k++) {
    if (entry + 12 > end) break;
    if (u16(entry) == 0x0112) {
      final v = u16(entry + 8); // SHORT: valor inline en el campo de 4 bytes
      return (v >= 1 && v <= 8) ? v : null;
    }
    entry += 12;
  }
  return null;
}

int _u32be(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
