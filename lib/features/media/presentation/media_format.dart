/// Formateadores de presentación del catálogo de media. Puros y sin estado: la
/// galería y el detalle los comparten sin acoplarse a `intl` (no es dependencia
/// del repo). El call-site decide la zona horaria (pasa `.toLocal()` si quiere).
library;

import 'package:flutter/material.dart' show IconData, Icons;

/// Ícono representativo por familia de `contentType`; la identidad visual del
/// tipo es la misma en la miniatura de la galería y en el detalle. Un tipo no
/// catalogado cae al genérico de archivo.
IconData mediaTypeIcon(String contentType) {
  if (contentType.startsWith('image/')) return Icons.image_outlined;
  if (contentType.startsWith('video/')) return Icons.movie_outlined;
  if (contentType.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (contentType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Tamaño legible (base binaria 1024). Bytes crudos por debajo de 1 KiB; KB/MB/
/// GB con un decimal. Negativo (defensivo, no debería ocurrir) ⇒ "0 B".
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// Duración legible de un medio a partir de sus milisegundos. `m:ss` por debajo
/// de una hora; `h:mm:ss` a partir de una hora. Trunca al segundo inferior.
/// Cero o negativo (defensivo) ⇒ `0:00`. El call-site sólo la muestra cuando
/// hay duración conocida (`> 0`); este `0:00` es la red de seguridad.
String formatDuration(int milliseconds) {
  if (milliseconds <= 0) return '0:00';
  final totalSeconds = milliseconds ~/ 1000;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '$m:${two(s)}';
}

/// Fecha/hora como `dd/MM/yyyy HH:mm`, formateando los campos del [dt] tal cual
/// (UTC o local según lo que pase el call-site). Padding de dos dígitos.
String formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
