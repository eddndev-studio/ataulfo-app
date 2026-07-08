import 'package:ataulfo/features/calendar/data/datasources/calendar_datasource.dart';
import 'package:ataulfo/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDs extends Mock implements CalendarDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppointmentStatus.cancelled);
  });

  late _MockDs dsMock;
  late CalendarRepositoryImpl repo;

  setUp(() {
    dsMock = _MockDs();
    repo = CalendarRepositoryImpl(datasource: dsMock);
  });

  test('listEventTypes delega en el datasource', () async {
    const et = EventType(
      id: 'et1',
      name: 'X',
      description: '',
      durationMin: 30,
      active: true,
    );
    when(
      () => dsMock.listEventTypes(),
    ).thenAnswer((_) async => <EventType>[et]);
    expect(await repo.listEventTypes(), <EventType>[et]);
    verify(() => dsMock.listEventTypes()).called(1);
  });

  test('setAppointmentStatus reenvía id + status', () async {
    when(
      () => dsMock.setAppointmentStatus(
        id: any(named: 'id'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async {});
    await repo.setAppointmentStatus(
      id: 'a1',
      status: AppointmentStatus.cancelled,
    );
    verify(
      () => dsMock.setAppointmentStatus(
        id: 'a1',
        status: AppointmentStatus.cancelled,
      ),
    ).called(1);
  });
}
