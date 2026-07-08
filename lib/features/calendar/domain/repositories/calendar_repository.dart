import '../entities/appointment.dart';
import '../entities/business_hours.dart';
import '../entities/event_type.dart';

/// Puerto del calendario: tipos de evento, horario de atención, disponibilidad
/// y citas. Las implementaciones lanzan `CalendarFailure` tipadas; nunca
/// DioException cruda. El dominio no conoce el transporte.
abstract interface class CalendarRepository {
  /// `GET /workspace/calendar/event-types` — todos los tipos (activos e
  /// inactivos) de la org activa. workerOnly: cualquier miembro los lee.
  Future<List<EventType>> listEventTypes();

  /// `POST /workspace/calendar/event-types` (ADMIN+). Devuelve el id del tipo
  /// recién creado. Nace activo.
  Future<String> createEventType({
    required String name,
    required String description,
    required int durationMin,
  });

  /// `PUT /workspace/calendar/event-types/{id}` (ADMIN+). Reemplaza los campos
  /// editables del tipo, incluido `active`.
  Future<void> updateEventType({
    required String id,
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  });

  /// `GET /workspace/calendar/hours` — todos los tramos de atención de la
  /// semana, sin orden garantizado.
  Future<List<BusinessHoursSlot>> getHours();

  /// `PUT /workspace/calendar/hours` (ADMIN+) — REEMPLAZO TOTAL del horario
  /// semanal. 422 si dos tramos del mismo día se cruzan.
  Future<void> putHours(List<BusinessHoursSlot> hours);

  /// `GET /workspace/calendar/availability` — instantes de inicio libres (UTC)
  /// para reservar un [eventTypeId] en el día LOCAL [date]. La hora de [date]
  /// se ignora: cuenta el día calendario local.
  Future<List<DateTime>> availability({
    required String eventTypeId,
    required DateTime date,
  });

  /// `GET /workspace/calendar/appointments?from&to` — citas cuyo inicio cae en
  /// `[from, to)` (instantes UTC). Para la agenda de un día, [from]=medianoche
  /// local y [to]=medianoche del día siguiente, convertidas a UTC.
  Future<List<Appointment>> appointments({
    required DateTime from,
    required DateTime to,
  });

  /// `GET /workspace/calendar/appointments?botId&chatLid` — citas ligadas a un
  /// chat concreto. Alimenta el badge de cita en el hilo.
  Future<List<Appointment>> appointmentsByChat({
    required String botId,
    required String chatLid,
  });

  /// `POST /workspace/calendar/appointments` — reserva manual. Devuelve el id
  /// de la cita creada. 409 si el hueco ya está tomado; 422 si es inválida.
  Future<String> createAppointment({
    required String eventTypeId,
    required DateTime start,
    required String customerName,
    required String note,
  });

  /// `POST /workspace/calendar/appointments/{id}/status` (OPERATOR+). Solo
  /// acepta [AppointmentStatus.cancelled], [AppointmentStatus.completed] o
  /// [AppointmentStatus.noShow]: son las transiciones que un humano dispara
  /// sobre una cita confirmada.
  Future<void> setAppointmentStatus({
    required String id,
    required AppointmentStatus status,
  });
}
