/// Lectura humana de una duración en h/min/s: componentes en cero se omiten
/// («1 min 30 s», «45 s», «1 h»); la duración cero se lee «0 s». Es la voz
/// única del kit para duraciones legibles: cualquier control que muestre
/// un valor de tiempo (readouts, labels de rango) habla igual.
String formatAppDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final parts = <String>[
    if (hours > 0) '$hours h',
    if (minutes > 0) '$minutes min',
    if (seconds > 0) '$seconds s',
  ];
  if (parts.isEmpty) return '0 s';
  return parts.join(' ');
}
