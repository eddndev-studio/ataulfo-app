import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Appointment make({
    String id = 'a1',
    String? botId = 'b1',
    String? chatLid = '5215500000000@s.whatsapp.net',
    AppointmentStatus status = AppointmentStatus.confirmed,
    AppointmentCreatedBy createdBy = AppointmentCreatedBy.ai,
  }) => Appointment(
    id: id,
    eventTypeId: 'et1',
    eventTypeName: 'Consulta',
    botId: botId,
    chatLid: chatLid,
    customerName: 'Ana',
    note: 'primera vez',
    startAt: DateTime.utc(2026, 7, 15, 16, 0),
    endAt: DateTime.utc(2026, 7, 15, 16, 30),
    status: status,
    createdBy: createdBy,
  );

  group('Appointment igualdad por valor', () {
    test('mismos campos ⇒ iguales y mismo hashCode', () {
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
    });

    test('id o estado distinto ⇒ desiguales', () {
      expect(make() == make(id: 'a2'), isFalse);
      expect(make() == make(status: AppointmentStatus.cancelled), isFalse);
      expect(make() == make(createdBy: AppointmentCreatedBy.operator), isFalse);
    });
  });

  group('hasChat', () {
    test('ambos ids presentes ⇒ true', () {
      expect(make().hasChat, isTrue);
    });

    test('sin botId ni chatLid ⇒ false', () {
      expect(make(botId: null, chatLid: null).hasChat, isFalse);
    });
  });
}
