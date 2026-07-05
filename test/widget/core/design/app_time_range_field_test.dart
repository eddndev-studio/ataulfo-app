import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_time_range_field.dart';

void main() {
  const nineToSix = AppTimeRange(
    start: TimeOfDay(hour: 9, minute: 0),
    end: TimeOfDay(hour: 18, minute: 0),
  );

  Finder startField() => find.byKey(const Key('app_time_range_field.start'));
  Finder endField() => find.byKey(const Key('app_time_range_field.end'));

  Future<void> pumpField(WidgetTester tester, Widget field) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
  }

  group('AppTimeRange — valor', () {
    test('igualdad estructural y startBeforeEnd', () {
      expect(
        nineToSix,
        const AppTimeRange(
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 18, minute: 0),
        ),
      );
      expect(nineToSix.startBeforeEnd, isTrue);
      // Inicio igual al final NO cuenta como ordenado: la ventana sería vacía.
      const collapsed = AppTimeRange(
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 9, minute: 0),
      );
      expect(collapsed.startBeforeEnd, isFalse);
      const crossing = AppTimeRange(
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 2, minute: 0),
      );
      expect(crossing.startBeforeEnd, isFalse);
    });
  });

  group('AppTimeRangeField — anatomía', () {
    testWidgets(
      'pinta dos campos hh:mm con el valor formateado a dos dígitos',
      (tester) async {
        await pumpField(
          tester,
          AppTimeRangeField(value: nineToSix, onChanged: (_) {}),
        );
        expect(find.text('Desde'), findsOneWidget);
        expect(find.text('Hasta'), findsOneWidget);
        expect(find.text('09:00'), findsOneWidget);
        expect(find.text('18:00'), findsOneWidget);
        // Campos de texto del kit, no un diálogo de reloj de Material.
        expect(find.byType(TextField), findsNWidgets(2));
      },
    );
  });

  group('AppTimeRangeField — edición', () {
    testWidgets('editar el inicio con hh:mm válido emite el rango nuevo', (
      tester,
    ) async {
      AppTimeRange? received;
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
      );
      await tester.enterText(startField(), '10:30');
      expect(
        received,
        const AppTimeRange(
          start: TimeOfDay(hour: 10, minute: 30),
          end: TimeOfDay(hour: 18, minute: 0),
        ),
      );
    });

    testWidgets('acepta hora sin cero inicial ("9:15")', (tester) async {
      AppTimeRange? received;
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
      );
      await tester.enterText(endField(), '9:15');
      expect(received?.end, const TimeOfDay(hour: 9, minute: 15));
    });

    testWidgets('un texto no interpretable marca el campo y no emite', (
      tester,
    ) async {
      AppTimeRange? received;
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
      );
      await tester.enterText(startField(), '9:');
      await tester.pump();
      expect(received, isNull);
      expect(find.text('Usa hh:mm'), findsOneWidget);
    });

    testWidgets('una hora fuera de rango (25:00, 09:75) no emite', (
      tester,
    ) async {
      AppTimeRange? received;
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
      );
      await tester.enterText(startField(), '25:00');
      await tester.pump();
      expect(received, isNull);
      await tester.enterText(startField(), '09:75');
      await tester.pump();
      expect(received, isNull);
      expect(find.text('Usa hh:mm'), findsOneWidget);
    });

    testWidgets(
      'corregir el texto inválido limpia la marca y vuelve a emitir',
      (tester) async {
        AppTimeRange? received;
        await pumpField(
          tester,
          AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
        );
        await tester.enterText(startField(), '9:');
        await tester.pump();
        await tester.enterText(startField(), '09:30');
        await tester.pump();
        expect(find.text('Usa hh:mm'), findsNothing);
        expect(received?.start, const TimeOfDay(hour: 9, minute: 30));
      },
    );
  });

  group('AppTimeRangeField — orden inicio<fin', () {
    testWidgets('inicio ≥ fin muestra el motivo junto a los campos', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (_) {}),
      );
      await tester.enterText(startField(), '20:00');
      await tester.pump();
      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsOneWidget,
      );
      final msg = tester.widget<Text>(
        find.text('La hora de inicio debe ser anterior al final'),
      );
      expect(msg.style?.color, AppTokens.danger);
    });

    testWidgets('el rango desordenado SÍ se emite: el consumer decide', (
      tester,
    ) async {
      // El campo avisa pero no secuestra el estado: como todo widget
      // controlado del kit, reporta lo tecleado y el guardado lo gatea el
      // consumer con su propia regla.
      AppTimeRange? received;
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (r) => received = r),
      );
      await tester.enterText(startField(), '20:00');
      expect(received?.start, const TimeOfDay(hour: 20, minute: 0));
      expect(received?.startBeforeEnd, isFalse);
    });

    testWidgets('con requireStartBeforeEnd false no hay aviso de orden '
        '(rangos que cruzan medianoche a criterio del consumer)', (
      tester,
    ) async {
      await pumpField(
        tester,
        AppTimeRangeField(
          value: nineToSix,
          requireStartBeforeEnd: false,
          onChanged: (_) {},
        ),
      );
      await tester.enterText(startField(), '22:00');
      await tester.enterText(endField(), '02:00');
      await tester.pump();
      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsNothing,
      );
    });

    testWidgets('mientras un campo no interpreta, el aviso de orden calla', (
      tester,
    ) async {
      // Dos mensajes a la vez confunden: primero que el texto sea una hora,
      // después que el rango esté ordenado.
      await pumpField(
        tester,
        AppTimeRangeField(value: nineToSix, onChanged: (_) {}),
      );
      await tester.enterText(startField(), '20:00');
      await tester.enterText(endField(), '9:');
      await tester.pump();
      expect(
        find.text('La hora de inicio debe ser anterior al final'),
        findsNothing,
      );
    });
  });

  group('AppTimeRangeField — sincronía con el valor externo', () {
    testWidgets('un valor nuevo desde afuera reescribe los textos', (
      tester,
    ) async {
      var value = nineToSix;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return AppTimeRangeField(value: value, onChanged: (_) {});
              },
            ),
          ),
        ),
      );
      rebuild(() {
        value = const AppTimeRange(
          start: TimeOfDay(hour: 7, minute: 45),
          end: TimeOfDay(hour: 12, minute: 5),
        );
      });
      await tester.pump();
      expect(find.text('07:45'), findsOneWidget);
      expect(find.text('12:05'), findsOneWidget);
    });

    testWidgets('el eco del propio valor no pisa lo tecleado', (tester) async {
      // Consumer típico: recibe onChanged y devuelve el mismo valor por
      // rebuild. El texto "9:15" interpreta al mismo valor: reescribirlo a
      // "09:15" movería el caret mientras se teclea.
      var value = nineToSix;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return AppTimeRangeField(
                  value: value,
                  onChanged: (r) => rebuild(() => value = r),
                );
              },
            ),
          ),
        ),
      );
      await tester.enterText(startField(), '9:15');
      await tester.pump();
      expect(find.text('9:15'), findsOneWidget);
      expect(find.text('09:15'), findsNothing);
    });
  });

  group('AppTimeRangeField — estados', () {
    testWidgets('deshabilitado (onChanged null): campos inertes', (
      tester,
    ) async {
      await pumpField(
        tester,
        const AppTimeRangeField(value: nineToSix, onChanged: null),
      );
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      for (final f in fields) {
        expect(f.enabled, isFalse);
      }
    });
  });
}
