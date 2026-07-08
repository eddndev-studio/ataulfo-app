import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/chat_appointment_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

Appointment at(
  DateTime startUtc, {
  AppointmentStatus status = AppointmentStatus.confirmed,
  String id = 'a',
}) => Appointment(
  id: id,
  eventTypeId: 'et1',
  eventTypeName: 'Consulta',
  botId: 'b1',
  chatLid: 'c1',
  customerName: 'Ana',
  note: '',
  startAt: startUtc,
  endAt: startUtc.add(const Duration(minutes: 30)),
  status: status,
  createdBy: AppointmentCreatedBy.ai,
);

void main() {
  final now = DateTime.utc(2026, 7, 8, 12, 0);

  ChatAppointmentCubit build(_MockRepo repo) =>
      ChatAppointmentCubit(repo, botId: 'b1', chatLid: 'c1', clock: now);

  test(
    'elige la próxima confirmada y futura (ignora pasadas y no-confirmadas)',
    () async {
      final repo = _MockRepo();
      when(
        () => repo.appointmentsByChat(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
        ),
      ).thenAnswer(
        (_) async => <Appointment>[
          at(DateTime.utc(2026, 7, 8, 9), id: 'pasada'), // pasada
          at(
            DateTime.utc(2026, 7, 8, 18),
            id: 'cancelada',
            status: AppointmentStatus.cancelled,
          ),
          at(DateTime.utc(2026, 7, 8, 20), id: 'lejana'),
          at(DateTime.utc(2026, 7, 8, 15), id: 'proxima'),
        ],
      );

      final cubit = build(repo);
      await cubit.load();

      final state = cubit.state;
      expect(state, isA<ChatAppointmentLoaded>());
      expect((state as ChatAppointmentLoaded).next?.id, 'proxima');
    },
  );

  test('sin citas futuras ⇒ Loaded(null)', () async {
    final repo = _MockRepo();
    when(
      () => repo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenAnswer((_) async => <Appointment>[at(DateTime.utc(2026, 7, 8, 9))]);

    final cubit = build(repo);
    await cubit.load();

    expect(cubit.state, isA<ChatAppointmentLoaded>());
    expect((cubit.state as ChatAppointmentLoaded).next, isNull);
  });

  test('falla ⇒ Hidden (silencioso, nunca molesta)', () async {
    final repo = _MockRepo();
    when(
      () => repo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenThrow(const CalendarNetworkFailure());

    final cubit = build(repo);
    await cubit.load();

    expect(cubit.state, isA<ChatAppointmentHidden>());
  });
}
