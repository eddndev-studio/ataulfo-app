/// Marca de tiempo "inteligente" para listas y burbujas de chat: la hora a
/// secas sólo informa si el instante es de hoy; para días anteriores el
/// usuario necesita la fecha. Formateo manual para no arrastrar `intl` por
/// un caption.
///
/// Reglas por día calendario LOCAL respecto de `now`:
/// - hoy            → `HH:mm`
/// - ayer           → `Ayer HH:mm`
/// - mismo año      → `DD/MM HH:mm`
/// - año distinto   → `DD/MM/YY HH:mm`
///
/// `now` es inyectable para tests deterministas; por defecto el reloj real.
String smartTimestamp(int timestampMs, {DateTime? now}) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final ref = now ?? DateTime.now();

  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(dt.hour)}:${two(dt.minute)}';

  final day = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  if (day == today) {
    return hm;
  }
  // Día calendario puro (day-1 normaliza mes/año); restar una Duration se
  // desviaría una hora en zonas con DST.
  if (day == DateTime(ref.year, ref.month, ref.day - 1)) {
    return 'Ayer $hm';
  }
  final dm = '${two(dt.day)}/${two(dt.month)}';
  if (dt.year == ref.year) {
    return '$dm $hm';
  }
  return '$dm/${two(dt.year % 100)} $hm';
}

/// Etiqueta de DÍA para los separadores del hilo (sin hora): mismas reglas
/// calendario-local que [smartTimestamp].
/// - hoy          → `Hoy`
/// - ayer         → `Ayer`
/// - mismo año    → `DD/MM`
/// - año distinto → `DD/MM/YY`
String dayLabel(int timestampMs, {DateTime? now}) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final ref = now ?? DateTime.now();

  String two(int v) => v.toString().padLeft(2, '0');

  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == DateTime(ref.year, ref.month, ref.day)) {
    return 'Hoy';
  }
  if (day == DateTime(ref.year, ref.month, ref.day - 1)) {
    return 'Ayer';
  }
  final dm = '${two(dt.day)}/${two(dt.month)}';
  return dt.year == ref.year ? dm : '$dm/${two(dt.year % 100)}';
}
