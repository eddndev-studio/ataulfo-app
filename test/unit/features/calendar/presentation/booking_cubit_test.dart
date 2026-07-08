import 'package:ataulfo/features/calendar/domain/entities/event_type.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/booking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

const _active = EventType(
  id: 'et1',
  name: 'Consulta',
  description: '',
  durationMin: 30,
  active: true,
);
const _inactive = EventType(
  id: 'et2',
  name: 'Vieja',
  description: '',
  durationMin: 30,
  active: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  late _MockRepo repo;
  late BookingCubit cubit;

  setUp(() {
    repo = _MockRepo();
    cubit = BookingCubit(repo);
  });

  test('loadEventTypes filtra solo activos', () async {
    when(
      repo.listEventTypes,
    ).thenAnswer((_) async => const <EventType>[_active, _inactive]);
    await cubit.loadEventTypes();
    expect(cubit.state.typesStatus, BookingTypesStatus.loaded);
    expect(cubit.state.eventTypes, const <EventType>[_active]);
  });

  test('selectDate carga disponibilidad del tipo elegido', () async {
    when(
      () => repo.availability(
        eventTypeId: any(named: 'eventTypeId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer(
      (_) async => <DateTime>[
        DateTime.utc(2026, 7, 15, 16, 0),
        DateTime.utc(2026, 7, 15, 16, 30),
      ],
    );

    cubit.selectEventType(_active);
    await cubit.selectDate(DateTime(2026, 7, 15, 9));

    expect(cubit.state.slotsStatus, SlotsStatus.loaded);
    expect(cubit.state.slots, hasLength(2));
    verify(
      () => repo.availability(eventTypeId: 'et1', date: DateTime(2026, 7, 15)),
    ).called(1);
  });

  test('cambiar de tipo olvida fecha, slots y slot elegido', () async {
    when(
      () => repo.availability(
        eventTypeId: any(named: 'eventTypeId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => <DateTime>[DateTime.utc(2026, 7, 15, 16, 0)]);
    cubit.selectEventType(_active);
    await cubit.selectDate(DateTime(2026, 7, 15));
    cubit.selectSlot(DateTime.utc(2026, 7, 15, 16, 0));

    cubit.selectEventType(_active);

    expect(cubit.state.date, isNull);
    expect(cubit.state.slots, isEmpty);
    expect(cubit.state.selectedSlot, isNull);
  });

  test('book ok ⇒ crea la cita con el slot elegido, devuelve null', () async {
    when(
      () => repo.createAppointment(
        eventTypeId: any(named: 'eventTypeId'),
        start: any(named: 'start'),
        customerName: any(named: 'customerName'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => 'a9');
    cubit.selectEventType(_active);
    cubit.selectSlot(DateTime.utc(2026, 7, 15, 16, 0));

    final f = await cubit.book(customerName: 'Ana', note: 'x');

    expect(f, isNull);
    verify(
      () => repo.createAppointment(
        eventTypeId: 'et1',
        start: DateTime.utc(2026, 7, 15, 16, 0),
        customerName: 'Ana',
        note: 'x',
      ),
    ).called(1);
  });

  test('book con 409 ⇒ devuelve Conflict', () async {
    when(
      () => repo.createAppointment(
        eventTypeId: any(named: 'eventTypeId'),
        start: any(named: 'start'),
        customerName: any(named: 'customerName'),
        note: any(named: 'note'),
      ),
    ).thenThrow(const CalendarConflictFailure());
    cubit.selectEventType(_active);
    cubit.selectSlot(DateTime.utc(2026, 7, 15, 16, 0));

    final f = await cubit.book(customerName: 'Ana', note: '');

    expect(f, isA<CalendarConflictFailure>());
    expect(cubit.state.submitting, isFalse);
  });
}
