import 'package:ataulfo/features/calendar/data/dto/appointment_dto.dart';
import 'package:ataulfo/features/calendar/data/dto/business_hours_dto.dart';
import 'package:ataulfo/features/calendar/data/dto/event_type_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventTypeDto.fromJson', () {
    test('objeto completo ⇒ DTO', () {
      final dto = EventTypeDto.fromJson(<String, dynamic>{
        'id': 'et1',
        'name': 'Consulta',
        'description': 'desc',
        'durationMin': 30,
        'active': true,
      });
      expect(dto.id, 'et1');
      expect(dto.durationMin, 30);
      expect(dto.active, isTrue);
    });

    test('clave faltante ⇒ FormatException', () {
      expect(
        () => EventTypeDto.fromJson(<String, dynamic>{'id': 'et1'}),
        throwsFormatException,
      );
    });

    test('tipo inválido (durationMin string) ⇒ FormatException', () {
      expect(
        () => EventTypeDto.fromJson(<String, dynamic>{
          'id': 'et1',
          'name': 'x',
          'description': '',
          'durationMin': '30',
          'active': true,
        }),
        throwsFormatException,
      );
    });
  });

  group('BusinessHoursSlotDto', () {
    test('fromJson objeto válido ⇒ DTO; toJson espeja claves', () {
      final dto = BusinessHoursSlotDto.fromJson(<String, dynamic>{
        'weekday': 1,
        'openMin': 540,
        'closeMin': 1080,
      });
      expect(dto.weekday, 1);
      expect(dto.toJson(), <String, dynamic>{
        'weekday': 1,
        'openMin': 540,
        'closeMin': 1080,
      });
    });

    test('minutos no enteros ⇒ FormatException', () {
      expect(
        () => BusinessHoursSlotDto.fromJson(<String, dynamic>{
          'weekday': 1,
          'openMin': 540.5,
          'closeMin': 1080,
        }),
        throwsFormatException,
      );
    });
  });

  group('AppointmentDto.fromJson', () {
    Map<String, dynamic> full() => <String, dynamic>{
      'id': 'a1',
      'eventTypeId': 'et1',
      'eventTypeName': 'Consulta',
      'botId': 'b1',
      'chatLid': 'c1',
      'customerName': 'Ana',
      'note': 'nota',
      'startAt': '2026-07-15T16:00:00Z',
      'endAt': '2026-07-15T16:30:00Z',
      'status': 'CONFIRMED',
      'createdBy': 'AI',
    };

    test('objeto completo ⇒ DTO con status/createdBy crudos', () {
      final dto = AppointmentDto.fromJson(full());
      expect(dto.status, 'CONFIRMED');
      expect(dto.createdBy, 'AI');
      expect(dto.botId, 'b1');
    });

    test('botId/chatLid null ⇒ tolerado (reserva manual sin chat)', () {
      final json = full()
        ..['botId'] = null
        ..['chatLid'] = null;
      final dto = AppointmentDto.fromJson(json);
      expect(dto.botId, isNull);
      expect(dto.chatLid, isNull);
    });

    test('note ausente ⇒ cadena vacía', () {
      final json = full()..remove('note');
      expect(AppointmentDto.fromJson(json).note, '');
    });

    test('startAt faltante ⇒ FormatException', () {
      final json = full()..remove('startAt');
      expect(() => AppointmentDto.fromJson(json), throwsFormatException);
    });
  });
}
