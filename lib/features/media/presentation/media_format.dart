/// Formateadores de presentación del catálogo de media. Puros y sin estado: la
/// galería y el detalle los comparten sin acoplarse a `intl` (no es dependencia
/// del repo). El call-site decide la zona horaria (pasa `.toLocal()` si quiere).
library;

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

/// Fecha/hora como `dd/MM/yyyy HH:mm`, formateando los campos del [dt] tal cual
/// (UTC o local según lo que pase el call-site). Padding de dos dígitos.
String formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
