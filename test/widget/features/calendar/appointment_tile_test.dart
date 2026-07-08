import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/calendar/domain/entities/appointment.dart';
import 'package:ataulfo/features/calendar/presentation/widgets/appointment_status_chip.dart';
import 'package:ataulfo/features/calendar/presentation/widgets/appointment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appt({
  AppointmentStatus status = AppointmentStatus.confirmed,
  AppointmentCreatedBy createdBy = AppointmentCreatedBy.ai,
  String customerName = 'Ana López',
}) => Appointment(
  id: 'a1',
  eventTypeId: 'et1',
  eventTypeName: 'Consulta inicial',
  botId: null,
  chatLid: null,
  customerName: customerName,
  note: '',
  startAt: DateTime.utc(2026, 7, 15, 16, 0),
  endAt: DateTime.utc(2026, 7, 15, 16, 30),
  status: status,
  createdBy: createdBy,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('tile muestra tipo, cliente y badge IA cuando createdBy=AI', (
    tester,
  ) async {
    await _pump(tester, AppointmentTile(appointment: _appt(), onTap: () {}));
    expect(find.text('Consulta inicial'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('IA'), findsOneWidget);
    expect(find.byType(AppointmentStatusChip), findsOneWidget);
  });

  testWidgets('sin autoría IA no pinta badge', (tester) async {
    await _pump(
      tester,
      AppointmentTile(
        appointment: _appt(createdBy: AppointmentCreatedBy.operator),
        onTap: () {},
      ),
    );
    expect(find.text('IA'), findsNothing);
  });

  testWidgets('cita cancelada tacha el título', (tester) async {
    await _pump(
      tester,
      AppointmentTile(
        appointment: _appt(status: AppointmentStatus.cancelled),
        onTap: () {},
      ),
    );
    final title = tester.widget<Text>(find.text('Consulta inicial'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('tap invoca onTap', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      AppointmentTile(appointment: _appt(), onTap: () => tapped = true),
    );
    await tester.tap(find.byType(AppointmentTile));
    expect(tapped, isTrue);
  });

  testWidgets('cliente vacío cae a "Sin nombre"', (tester) async {
    await _pump(
      tester,
      AppointmentTile(
        appointment: _appt(customerName: ''),
        onTap: () {},
      ),
    );
    expect(find.text('Sin nombre'), findsOneWidget);
  });

  testWidgets('el chip de estado muestra la etiqueta es-MX', (tester) async {
    await _pump(
      tester,
      const AppointmentStatusChip(status: AppointmentStatus.noShow),
    );
    expect(find.text('No asistió'), findsOneWidget);
  });
}
