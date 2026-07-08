import 'package:ataulfo/features/calendar/data/dto/appointment_dto.dart';
import 'package:ataulfo/features/calendar/data/mappers/appointment_mapper.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppointmentDto dto({
    String status = 'CONFIRMED',
    String createdBy = 'AI',
    String startAt = '2026-07-15T16:00:00Z',
  }) => AppointmentDto(
    id: 'a1',
    eventTypeId: 'et1',
    eventTypeName: 'Consulta',
    botId: null,
    chatLid: null,
    customerName: 'Ana',
    note: '',
    startAt: startAt,
    endAt: '2026-07-15T16:30:00Z',
    status: status,
    createdBy: createdBy,
  );

  group('AppointmentMapper.dtoToEntity', () {
    test('parsea instantes a DateTime UTC', () {
      final a = AppointmentMapper.dtoToEntity(dto());
      expect(a.startAt.isUtc, isTrue);
      expect(a.startAt, DateTime.utc(2026, 7, 15, 16, 0));
      expect(a.endAt, DateTime.utc(2026, 7, 15, 16, 30));
    });

    test('interpreta el conjunto cerrado de status', () {
      expect(
        AppointmentMapper.dtoToEntity(dto(status: 'CANCELLED')).status,
        AppointmentStatus.cancelled,
      );
      expect(
        AppointmentMapper.dtoToEntity(dto(status: 'COMPLETED')).status,
        AppointmentStatus.completed,
      );
      expect(
        AppointmentMapper.dtoToEntity(dto(status: 'NO_SHOW')).status,
        AppointmentStatus.noShow,
      );
    });

    test('interpreta createdBy', () {
      expect(
        AppointmentMapper.dtoToEntity(dto(createdBy: 'OPERATOR')).createdBy,
        AppointmentCreatedBy.operator,
      );
    });

    test('status desconocido ⇒ FormatException (wire roto)', () {
      expect(
        () => AppointmentMapper.dtoToEntity(dto(status: 'PENDING')),
        throwsFormatException,
      );
    });

    test('createdBy desconocido ⇒ FormatException', () {
      expect(
        () => AppointmentMapper.dtoToEntity(dto(createdBy: 'SYSTEM')),
        throwsFormatException,
      );
    });
  });

  group('AppointmentMapper.statusToWire', () {
    test('mapea cada estado a su string de wire', () {
      expect(
        AppointmentMapper.statusToWire(AppointmentStatus.cancelled),
        'CANCELLED',
      );
      expect(
        AppointmentMapper.statusToWire(AppointmentStatus.completed),
        'COMPLETED',
      );
      expect(
        AppointmentMapper.statusToWire(AppointmentStatus.noShow),
        'NO_SHOW',
      );
      expect(
        AppointmentMapper.statusToWire(AppointmentStatus.confirmed),
        'CONFIRMED',
      );
    });
  });
}
