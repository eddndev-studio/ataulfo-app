import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/agenda_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

Appointment appt(
  String id,
  int hour, {
  AppointmentStatus status = AppointmentStatus.confirmed,
}) => Appointment(
  id: id,
  eventTypeId: 'et1',
  eventTypeName: 'Consulta',
  botId: null,
  chatLid: null,
  customerName: 'Ana',
  note: '',
  startAt: DateTime.utc(2026, 7, 8, hour, 0),
  endAt: DateTime.utc(2026, 7, 8, hour, 30),
  status: status,
  createdBy: AppointmentCreatedBy.operator,
);

void main() {
  setUpAll(() {
    registerFallbackValue(AppointmentStatus.cancelled);
  });

  final today = DateTime(2026, 7, 8, 15, 0);

  test('estado inicial = loading en el día de hoy (sin hora)', () {
    final c = AgendaCubit(_MockRepo(), today: today);
    expect(c.state.status, AgendaStatus.loading);
    expect(c.state.day, DateTime(2026, 7, 8));
  });

  blocTest<AgendaCubit, AgendaState>(
    'load ok ⇒ [loading, loaded ordenado por inicio]',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.appointments(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => <Appointment>[appt('b', 11), appt('a', 9)]);
      return AgendaCubit(repo, today: today);
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<AgendaState>().having(
        (s) => s.status,
        'status',
        AgendaStatus.loading,
      ),
      isA<AgendaState>()
          .having((s) => s.status, 'status', AgendaStatus.loaded)
          .having(
            (s) => s.appointments.map((a) => a.id).toList(),
            'orden',
            <String>['a', 'b'],
          ),
    ],
  );

  blocTest<AgendaCubit, AgendaState>(
    'load con fallo ⇒ error con failure',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.appointments(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenThrow(const CalendarNetworkFailure());
      return AgendaCubit(repo, today: today);
    },
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<AgendaState>().having(
        (s) => s.status,
        'status',
        AgendaStatus.loading,
      ),
      isA<AgendaState>()
          .having((s) => s.status, 'status', AgendaStatus.error)
          .having((s) => s.failure, 'failure', const CalendarNetworkFailure()),
    ],
  );

  blocTest<AgendaCubit, AgendaState>(
    'nextDay avanza un día y recarga',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.appointments(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => <Appointment>[]);
      return AgendaCubit(repo, today: today);
    },
    act: (c) => c.nextDay(),
    verify: (c) {
      expect(c.state.day, DateTime(2026, 7, 9));
    },
  );

  blocTest<AgendaCubit, AgendaState>(
    'setStatus ok ⇒ mutating y recarga silenciosa (sin volver a loading)',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.setAppointmentStatus(
          id: any(named: 'id'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async {});
      var calls = 0;
      when(
        () => repo.appointments(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? <Appointment>[appt('a', 9)]
            : <Appointment>[appt('a', 9, status: AppointmentStatus.cancelled)];
      });
      return AgendaCubit(repo, today: today);
    },
    act: (c) async {
      await c.load();
      final f = await c.setStatus('a', AppointmentStatus.cancelled);
      expect(f, isNull);
    },
    verify: (c) {
      expect(c.state.appointments.single.status, AppointmentStatus.cancelled);
      expect(c.state.mutating, isFalse);
      // La recarga silenciosa nunca pasa por loading tras el load inicial.
      expect(c.state.status, AgendaStatus.loaded);
    },
  );

  blocTest<AgendaCubit, AgendaState>(
    'setStatus con fallo ⇒ devuelve la failure y baja mutating',
    build: () {
      final repo = _MockRepo();
      when(
        () => repo.appointments(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => <Appointment>[appt('a', 9)]);
      when(
        () => repo.setAppointmentStatus(
          id: any(named: 'id'),
          status: any(named: 'status'),
        ),
      ).thenThrow(const CalendarConflictFailure());
      return AgendaCubit(repo, today: today);
    },
    act: (c) async {
      await c.load();
      final f = await c.setStatus('a', AppointmentStatus.completed);
      expect(f, isA<CalendarConflictFailure>());
    },
    verify: (c) {
      expect(c.state.mutating, isFalse);
      expect(c.state.appointments, hasLength(1));
    },
  );
}
