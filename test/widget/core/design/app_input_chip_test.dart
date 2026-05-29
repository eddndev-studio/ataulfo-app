import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_input_chip.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, Widget chip) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: chip)));
  }

  // El contrato visual vive en el Container raíz del chip: fondo + radio. Se
  // lee el primer Container descendiente igual que en los demás primitivos.
  Container chipContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppInputChip),
        matching: find.byType(Container),
      ),
    );
  }

  TextStyle? labelStyle(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style;
  }

  group('AppInputChip — render', () {
    testWidgets('renderiza el label', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      expect(find.text('Diseño'), findsOneWidget);
    });

    testWidgets('renderiza el icono trailing de borrar (close)', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('AppInputChip — contrato visual', () {
    testWidgets('fondo en primary (amarillo de marca)', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      final d = chipContainer(tester).decoration as BoxDecoration;
      expect(d.color, AppTokens.primary);
    });

    testWidgets('radio en radiusChip (8)', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      final d = chipContainer(tester).decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusChip));
    });

    testWidgets('label en onPrimary (oscuro sobre fill cálido)', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      expect(labelStyle(tester, 'Diseño')?.color, AppTokens.onPrimary);
    });

    testWidgets('icono close en onPrimary', (tester) async {
      await pumpChip(tester, const AppInputChip(label: 'Diseño'));
      final icon = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(icon.color, AppTokens.onPrimary);
    });
  });

  group('AppInputChip — interacción', () {
    testWidgets('tap en el icono close dispara onDeleted', (tester) async {
      var deleted = 0;
      await pumpChip(
        tester,
        AppInputChip(label: 'Diseño', onDeleted: () => deleted++),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });

    testWidgets('tap en el cuerpo dispara onPressed', (tester) async {
      // Se toca el label (cuerpo del chip), no el icono close: así el gesto
      // del cuerpo no se confunde con el de borrar.
      var pressed = 0;
      await pumpChip(
        tester,
        AppInputChip(label: 'Diseño', onPressed: () => pressed++),
      );
      await tester.tap(find.text('Diseño'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('tap en el cuerpo NO dispara onDeleted', (tester) async {
      // El cuerpo y el botón de borrar son zonas de toque independientes.
      var deleted = 0;
      await pumpChip(
        tester,
        AppInputChip(
          label: 'Diseño',
          onPressed: () {},
          onDeleted: () => deleted++,
        ),
      );
      await tester.tap(find.text('Diseño'));
      await tester.pumpAndSettle();
      expect(deleted, 0);
    });
  });
}
