import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ataulfo/features/calendar/presentation/widgets/chat_appointment_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CalendarRepository {}

Appointment _future() => Appointment(
  id: 'a1',
  eventTypeId: 'et1',
  eventTypeName: 'Consulta',
  botId: 'b1',
  chatLid: 'c1',
  customerName: 'Ana',
  note: '',
  startAt: DateTime.utc(2030, 1, 1, 16, 0),
  endAt: DateTime.utc(2030, 1, 1, 16, 30),
  status: AppointmentStatus.confirmed,
  createdBy: AppointmentCreatedBy.ai,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: ChatAppointmentBadge(
          repository: repo,
          botId: 'b1',
          chatLid: 'c1',
        ),
      ),
    ),
  );

  testWidgets('con próxima cita futura → chip visible', (tester) async {
    when(
      () => repo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenAnswer((_) async => <Appointment>[_future()]);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread.appointment_badge')), findsOneWidget);
    expect(find.textContaining('Cita:'), findsOneWidget);
  });

  testWidgets('sin citas → nada (SizedBox.shrink)', (tester) async {
    when(
      () => repo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenAnswer((_) async => <Appointment>[]);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread.appointment_badge')), findsNothing);
  });

  testWidgets('falla → nada (silencioso)', (tester) async {
    when(
      () => repo.appointmentsByChat(
        botId: any(named: 'botId'),
        chatLid: any(named: 'chatLid'),
      ),
    ).thenThrow(const CalendarNetworkFailure());
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread.appointment_badge')), findsNothing);
  });
}
