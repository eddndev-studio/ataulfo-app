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
      'unselected: fondo transparent, borde divider y label en text2',
      (tester) async {
        await pumpChip(
          tester,
          AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
        );
        final c = chipContainer(tester);
        final d = c.decoration as BoxDecoration;
        expect(d.color, Colors.transparent);
        expect(d.border?.top.color, AppTokens.divider);
        // Opción latente: label en text2 (secundario), no text1.
        expect(labelStyle(tester, 'Diario')?.color, AppTokens.text2);
      },
    );

    testWidgets('unselected: NO muestra el check', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: false, onSelected: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('selected: tinte primary (fondo primary@16% + borde y label '
        'primary), no fill lleno tipo CTA', (tester) async {
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: true, onSelected: (_) {}),
      );
      final c = chipContainer(tester);
      final d = c.decoration as BoxDecoration;
      // Selección discreta: tinte, no el fill amarillo pleno (que compite con
      // los CTAs). Geometría consistente: borde 1px en ambos estados.
      expect(d.color, AppTokens.primary.withValues(alpha: 0.16));
      expect(d.border?.top.color, AppTokens.primary);
      expect(labelStyle(tester, 'Diario')?.color, AppTokens.primary);
    });

    testWidgets('selected: muestra el check (Icons.check) tintado en primary', (
      tester,
    ) async {
      // Tinte primary: el check va en primary (no onPrimary), a juego con el
      // label y el borde. A la izquierda del label.
      await pumpChip(
        tester,
        AppChoiceChip(label: 'Diario', selected: true, onSelected: (_) {}),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      final check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, AppTokens.primary);
    });
  });

  group('AppChoiceChip — geometría', () {
    testWidgets('radio AppTokens.radiusPill (cápsula)', (tester) async {
      // El chip es una cápsula como el resto de la familia de toggles: un
      // borde cuadrado disuena con los demás componentes (botones/pills full).
      await pumpChip(
        tester,
        AppChoiceChip(label: 'x', selected: false, onSelected: (_) {}),
      );
      final c = chipContainer(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusPill));
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
