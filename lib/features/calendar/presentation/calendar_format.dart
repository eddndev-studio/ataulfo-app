import '../../../core/design/format_duration.dart';
import '../domain/entities/appointment.dart';

/// Voz de formato del calendario en es-MX. Todo manual (sin `intl`, como el
/// resto del kit) y SIEMPRE en hora local: los instantes de una cita llegan en
/// UTC y aquí se convierten con `toLocal()` antes de pintarse.
///
/// La semana usa la convención del wire (0=domingo … 6=sábado) para que los
/// nombres se indexen directo con `weekday` del backend y con
/// [wireWeekdayOf].

const List<String> _weekdayFull = <String>[
  'domingo',
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
];

const List<String> _weekdayShort = <String>[
  'dom',
  'lun',
  'mar',
  'mié',
  'jue',
  'vie',
  'sáb',
];

const List<String> _monthShort = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const List<String> _monthFull = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Índice de día del wire (0=domingo..6=sábado) de una fecha local.
/// `DateTime.weekday` es 1=lunes..7=domingo; `% 7` lo lleva a la convención.
int wireWeekdayOf(DateTime local) => local.weekday % 7;

/// Nombre completo del día por índice de wire (0=domingo..6=sábado).
String weekdayFull(int wireWeekday) => _weekdayFull[wireWeekday];

/// Nombre abreviado del día por índice de wire.
String weekdayShort(int wireWeekday) => _weekdayShort[wireWeekday];

/// Mes abreviado es-MX (1=enero..12=diciembre).
String monthShort(int month) => _monthShort[month - 1];

/// Mes completo es-MX (1=enero..12=diciembre).
String monthFull(int month) => _monthFull[month - 1];

/// Título de mes para el calendario: «Julio 2026» (mes capitalizado).
String monthYearLabel(DateTime month) {
  final name = monthFull(month.month);
  return '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
}

/// `HH:mm` de un instante local.
String hhmm(DateTime local) => '${_two(local.hour)}:${_two(local.minute)}';

/// Minutos desde medianoche → `HH:mm` (para el editor de horario).
String minutesToHhmm(int minutes) =>
    '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

/// Rango horario local de una cita (`HH:mm–HH:mm`) a partir de sus instantes
/// UTC.
String localTimeRange(DateTime startUtc, DateTime endUtc) =>
    '${hhmm(startUtc.toLocal())}–${hhmm(endUtc.toLocal())}';

/// Encabezado del día en la agenda, con prefijo relativo cuando aplica:
/// «Hoy · Miércoles 15 jul», «Mañana · …», «Ayer · …» o solo la fecha.
String agendaDayHeader(DateTime localDay, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final day = DateTime(localDay.year, localDay.month, localDay.day);
  final today = DateTime(ref.year, ref.month, ref.day);
  final full =
      '${weekdayFull(wireWeekdayOf(day))} ${day.day} ${monthShort(day.month)}';
  final cap = '${full[0].toUpperCase()}${full.substring(1)}';
  if (day == today) return 'Hoy · $cap';
  if (day == DateTime(ref.year, ref.month, ref.day + 1)) return 'Mañana · $cap';
  if (day == DateTime(ref.year, ref.month, ref.day - 1)) return 'Ayer · $cap';
  return cap;
}

/// Etiqueta corta de la próxima cita para el badge del chat: «mié 15 jul,
/// 10:00» (hora local).
String nextAppointmentLabel(DateTime startUtc) {
  final s = startUtc.toLocal();
  return '${weekdayShort(wireWeekdayOf(s))} ${s.day} '
      '${monthShort(s.month)}, ${hhmm(s)}';
}

/// Etiqueta humana del estado de una cita.
String appointmentStatusLabel(AppointmentStatus status) => switch (status) {
  AppointmentStatus.confirmed => 'Confirmada',
  AppointmentStatus.cancelled => 'Cancelada',
  AppointmentStatus.completed => 'Completada',
  AppointmentStatus.noShow => 'No asistió',
};

/// Duración de un tipo de evento en lectura humana («30 min», «1 h 30 min»).
String durationLabel(int durationMin) =>
    formatAppDuration(Duration(minutes: durationMin));
