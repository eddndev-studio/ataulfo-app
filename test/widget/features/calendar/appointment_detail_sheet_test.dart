import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/domain/failures/calendar_failure.dart';
import 'package:ataulfo/features/calendar/presentation/widgets/appointment_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appt() => Appointment(
  id: 'a1',
  eventTypeId: 'et1',
  eventTypeName: 'Consulta',
  botId: null,
  chatLid: null,
  customerName: 'Ana',
  note: '',
  startAt: DateTime.utc(2026, 7, 15, 16),
  endAt: DateTime.utc(2026, 7, 15, 16, 30),
  status: AppointmentStatus.confirmed,
  createdBy: AppointmentCreatedBy.operator,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<CalendarFailure?> Function(AppointmentStatus) onChange,
  }) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Material(
          child: AppointmentDetailSheet(
            appointment: _appt(),
            onStatusChange: onChange,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('cambiar status con plan sin agenda muestra la copy de plan '
      '(no la de rol)', (tester) async {
    await pump(
      tester,
      onChange: (_) async => const CalendarPlanRequiredFailure(),
    );
    await tester.tap(find.byKey(const Key('agenda.detail.complete')));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Tu plan no incluye la agenda. Mejora tu plan para usarla.'),
      findsOneWidget,
    );
    expect(find.text('No tienes permiso para esta acción.'), findsNothing);
  });

  testWidgets('cambiar status sin permiso conserva la copy de rol', (
    tester,
  ) async {
    await pump(tester, onChange: (_) async => const CalendarForbiddenFailure());
    await tester.tap(find.byKey(const Key('agenda.detail.complete')));
    await tester.pump();
    await tester.pump();
    expect(find.text('No tienes permiso para esta acción.'), findsOneWidget);
  });
}
