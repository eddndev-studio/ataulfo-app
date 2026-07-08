import '../../domain/entities/appointment.dart';
import '../dto/appointment_dto.dart';

/// Convierte el DTO de cita a la entidad: parsea los instantes RFC3339 a
/// `DateTime` UTC e interpreta los enums de estado/autoría. Un status o
/// createdBy fuera del conjunto cerrado es un wire roto ⇒ `FormatException`
/// (que el datasource traduce a `UnknownCalendarFailure`), no un caso mudo.
class AppointmentMapper {
  const AppointmentMapper._();

  static Appointment dtoToEntity(AppointmentDto dto) => Appointment(
    id: dto.id,
    eventTypeId: dto.eventTypeId,
    eventTypeName: dto.eventTypeName,
    botId: dto.botId,
    chatLid: dto.chatLid,
    customerName: dto.customerName,
    note: dto.note,
    startAt: _parseUtc(dto.startAt),
    endAt: _parseUtc(dto.endAt),
    status: _status(dto.status),
    createdBy: _createdBy(dto.createdBy),
  );

  static DateTime _parseUtc(String rfc3339) => DateTime.parse(rfc3339).toUtc();

  static AppointmentStatus _status(String wire) => switch (wire) {
    'CONFIRMED' => AppointmentStatus.confirmed,
    'CANCELLED' => AppointmentStatus.cancelled,
    'COMPLETED' => AppointmentStatus.completed,
    'NO_SHOW' => AppointmentStatus.noShow,
    _ => throw FormatException('appointment: status desconocido "$wire"'),
  };

  static AppointmentCreatedBy _createdBy(String wire) => switch (wire) {
    'AI' => AppointmentCreatedBy.ai,
    'OPERATOR' => AppointmentCreatedBy.operator,
    _ => throw FormatException('appointment: createdBy desconocido "$wire"'),
  };

  /// Serializa el estado destino de una transición para el
  /// `POST /appointments/{id}/status`. El backend solo acepta las tres
  /// transiciones humanas; `confirmed` no se envía (una cita nace confirmada).
  static String statusToWire(AppointmentStatus status) => switch (status) {
    AppointmentStatus.confirmed => 'CONFIRMED',
    AppointmentStatus.cancelled => 'CANCELLED',
    AppointmentStatus.completed => 'COMPLETED',
    AppointmentStatus.noShow => 'NO_SHOW',
  };
}
