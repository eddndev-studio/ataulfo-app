import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/presentation/calendar_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wireWeekdayOf', () {
    test('domingo=0, lunes=1, sábado=6', () {
      expect(wireWeekdayOf(DateTime(2026, 7, 5)), 0); // 5-jul-2026 = domingo
      expect(wireWeekdayOf(DateTime(2026, 7, 6)), 1); // lunes
      expect(wireWeekdayOf(DateTime(2026, 7, 11)), 6); // sábado
    });
  });

  group('nombres', () {
    test('weekday y mes es-MX', () {
      expect(weekdayFull(3), 'miércoles');
      expect(weekdayShort(3), 'mié');
      expect(monthShort(7), 'jul');
      expect(monthShort(1), 'ene');
    });
  });

  group('monthYearLabel', () {
    test('mes capitalizado + año', () {
      expect(monthYearLabel(DateTime(2026, 7)), 'Julio 2026');
      expect(monthYearLabel(DateTime(2026, 1)), 'Enero 2026');
    });
  });

  group('minutesToHhmm', () {
    test('formatea minutos desde medianoche', () {
      expect(minutesToHhmm(0), '00:00');
      expect(minutesToHhmm(540), '09:00');
      expect(minutesToHhmm(1080), '18:00');
      expect(minutesToHhmm(615), '10:15');
    });
  });

  group('localTimeRange', () {
    test('convierte instantes UTC a rango local HH:mm–HH:mm', () {
      // Se comparan contra la conversión local del propio test para no atar
      // el resultado a una zona horaria concreta del entorno de CI.
      final start = DateTime.utc(2026, 7, 15, 16, 0);
      final end = DateTime.utc(2026, 7, 15, 16, 30);
      final expected = '${hhmm(start.toLocal())}–${hhmm(end.toLocal())}';
      expect(localTimeRange(start, end), expected);
    });
  });

  group('agendaDayHeader', () {
    final now = DateTime(2026, 7, 8, 10, 0); // miércoles

    test('hoy lleva prefijo "Hoy ·" y capitaliza', () {
      expect(
        agendaDayHeader(DateTime(2026, 7, 8), now: now),
        'Hoy · Miércoles 8 jul',
      );
    });

    test('mañana / ayer', () {
      expect(
        agendaDayHeader(DateTime(2026, 7, 9), now: now),
        startsWith('Mañana · '),
      );
      expect(
        agendaDayHeader(DateTime(2026, 7, 7), now: now),
        startsWith('Ayer · '),
      );
    });

    test('otro día ⇒ solo la fecha capitalizada', () {
      expect(
        agendaDayHeader(DateTime(2026, 7, 15), now: now),
        'Miércoles 15 jul',
      );
    });
  });

  group('appointmentStatusLabel', () {
    test('cada estado tiene copy es-MX', () {
      expect(appointmentStatusLabel(AppointmentStatus.confirmed), 'Confirmada');
      expect(appointmentStatusLabel(AppointmentStatus.cancelled), 'Cancelada');
      expect(appointmentStatusLabel(AppointmentStatus.completed), 'Completada');
      expect(appointmentStatusLabel(AppointmentStatus.noShow), 'No asistió');
    });
  });

  group('durationLabel', () {
    test('múltiplos de 15 en lectura humana', () {
      expect(durationLabel(30), '30 min');
      expect(durationLabel(60), '1 h');
      expect(durationLabel(90), '1 h 30 min');
    });
  });
}
