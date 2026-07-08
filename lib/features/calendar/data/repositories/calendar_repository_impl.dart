import '../../domain/entities/appointment.dart';
import '../../domain/entities/business_hours.dart';
import '../../domain/entities/event_type.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/calendar_datasource.dart';

/// Delega en el datasource: no hay caché local del calendario (es estado vivo
/// —la disponibilidad y la agenda cambian entre lecturas—). Si una superficie
/// necesitara memoización, entra aquí sin tocar el puerto.
class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl({required CalendarDatasource datasource})
    : _ds = datasource;

  final CalendarDatasource _ds;

  @override
  Future<List<EventType>> listEventTypes() => _ds.listEventTypes();

  @override
  Future<String> createEventType({
    required String name,
    required String description,
    required int durationMin,
  }) => _ds.createEventType(
    name: name,
    description: description,
    durationMin: durationMin,
  );

  @override
  Future<void> updateEventType({
    required String id,
    required String name,
    required String description,
    required int durationMin,
    required bool active,
  }) => _ds.updateEventType(
    id: id,
    name: name,
    description: description,
    durationMin: durationMin,
    active: active,
  );

  @override
  Future<List<BusinessHoursSlot>> getHours() => _ds.getHours();

  @override
  Future<void> putHours(List<BusinessHoursSlot> hours) => _ds.putHours(hours);

  @override
  Future<List<DateTime>> availability({
    required String eventTypeId,
    required DateTime date,
  }) => _ds.availability(eventTypeId: eventTypeId, date: date);

  @override
  Future<List<Appointment>> appointments({
    required DateTime from,
    required DateTime to,
  }) => _ds.appointments(from: from, to: to);

  @override
  Future<List<Appointment>> appointmentsByChat({
    required String botId,
    required String chatLid,
  }) => _ds.appointmentsByChat(botId: botId, chatLid: chatLid);

  @override
  Future<String> createAppointment({
    required String eventTypeId,
    required DateTime start,
    required String customerName,
    required String note,
  }) => _ds.createAppointment(
    eventTypeId: eventTypeId,
    start: start,
    customerName: customerName,
    note: note,
  );

  @override
  Future<void> setAppointmentStatus({
    required String id,
    required AppointmentStatus status,
  }) => _ds.setAppointmentStatus(id: id, status: status);
}
