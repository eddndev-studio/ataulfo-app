import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, Widget chip) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: chip)));
  }

  Container chipContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppChoiceChip),
        matching: find.byType(Container),
      ),
    );
  }

  TextStyle? labelStyle(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style;
  }

  group('AppChoiceChip — label', () {
    testWidgets('renderiza el texto del label', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
      );
      expect(find.text('Diario'), findsOneWidget);
    });

    testWidgets('label en weight w600', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
      );
      expect(labelStyle(tester, 'Diario')?.fontWeight, FontWeight.w600);
    });
  });

  group('AppChoiceChip — unselected vs selected', () {
    testWidgets(
      'unselected: fondo transparent, borde divider y label en text1',
      (tester) async {
        await pumpChip(
          tester,
          AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
        );
        final c = chipContainer(tester);
        final d = c.decoration as BoxDecoration;
        expect(d.color, Colors.transparent);
        expect(d.border?.top.color, AppTokens.divider);
        expect(labelStyle(tester, 'Diario')?.color, AppTokens.text1);
      },
    );

    testWidgets('unselected: NO muestra el check', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('selected: fondo primary y label en onPrimary', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: true, onSelected: (_) {}),
      );
      final c = chipContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.primary);
      expect(labelStyle(tester, 'Diario')?.color, AppTokens.onPrimary);
    });

    testWidgets(
      'selected: muestra el check (Icons.check) tintado en onPrimary',
      (tester) async {
        // El check vive sobre el fill amarillo: foreground oscuro onPrimary,
        // nunca blanco. Va a la izquierda del label.
        await pumpChip(
          tester,
          AppChoiceChip(label: 'Diario', selected: true, onSelected: (_) {}),
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        final check = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(check.color, AppTokens.onPrimary);
      },
    );
  });

  group('AppChoiceChip — geometría', () {
    testWidgets('radio AppTokens.radiusChip (8)', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'x', selected: false, onSelected: (_) {}),
      );
      final c = chipContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusChip));
    });
  });

  group('AppChoiceChip — estados', () {
    testWidgets('onSelected null: opacity 0.4 y no tappable', (tester) async {
      // onSelected null bloquea el tap; la verificación visual es la opacity.
      // No hace falta contador: no hay callback que pudiera dispararse.
      await pumpChip(
        tester,
        const AppChoiceChip(label: 'x', selected: false, onSelected: null),
      );
      await tester.tap(find.byType(AppChoiceChip));
      await tester.pumpAndSettle();
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppChoiceChip),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('unselected: tap emite onSelected(true)', (tester) async {
      // El chip es controlado: el tap no alterna estado, emite el valor que
      // el consumer debería aplicar — el negado del [selected] actual.
      bool? received;
      await pumpChip(
        tester,
        AppChoiceChip(
          label: 'x',
          selected: false,
          onSelected: (value) => received = value,
        ),
      );
      await tester.tap(find.byType(AppChoiceChip));
      await tester.pumpAndSettle();
      expect(received, isTrue);
    });

    testWidgets('selected: tap emite onSelected(false)', (tester) async {
      bool? received;
      await pumpChip(
        tester,
        AppChoiceChip(
          label: 'x',
          selected: true,
          onSelected: (value) => received = value,
        ),
      );
      await tester.tap(find.byType(AppChoiceChip));
      await tester.pumpAndSettle();
      expect(received, isFalse);
    });
  });

  group('AppChoiceChip — semántica', () {
    testWidgets('expone rol de botón seleccionado con etiqueta', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diseño', selected: true, onSelected: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(AppChoiceChip)),
        containsSemantics(
          isButton: true,
          isSelected: true,
          label: 'Diseño',
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('no seleccionado: isSelected false', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diseño', selected: false, onSelected: (_) {}),
      );
      expect(
        tester.getSemantics(find.byType(AppChoiceChip)),
        containsSemantics(isButton: true, isSelected: false),
      );
      handle.dispose();
    });
  });
}
