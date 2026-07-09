import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_time_wheel_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('muestra la hora formateada hh:mm y la etiqueta', (tester) async {
    await tester.pumpWidget(
      host(
        AppTimeWheelField(
          label: 'Desde',
          value: const TimeOfDay(hour: 9, minute: 0),
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Desde'), findsOneWidget);
  });

  testWidgets('tocar abre la rueda y «Listo» emite el valor', (tester) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      host(
        AppTimeWheelField(
          label: 'Hasta',
          value: const TimeOfDay(hour: 18, minute: 30),
          onChanged: (v) => picked = v,
        ),
      ),
    );
    await tester.tap(find.text('18:30'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('time_wheel.done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('time_wheel.done')));
    await tester.pumpAndSettle();
    expect(picked, const TimeOfDay(hour: 18, minute: 30));
  });

  testWidgets('un minuto fuera de grilla se ajusta al bloque de 15', (
    tester,
  ) async {
    TimeOfDay? picked;
    await tester.pumpWidget(
      host(
        AppTimeWheelField(
          label: 'Desde',
          value: const TimeOfDay(hour: 9, minute: 7),
          onChanged: (v) => picked = v,
        ),
      ),
    );
    await tester.tap(find.text('09:07'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('time_wheel.done')));
    await tester.pumpAndSettle();
    // 9:07 cae en el bloque de :00.
    expect(picked, const TimeOfDay(hour: 9, minute: 0));
  });

  testWidgets('deshabilitado (onChanged null) no abre la rueda', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppTimeWheelField(
          label: 'Desde',
          value: TimeOfDay(hour: 9, minute: 0),
          onChanged: null,
        ),
      ),
    );
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('time_wheel.done')), findsNothing);
  });
}
