import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_day_chips.dart';

void main() {
  Future<void> pumpChips(WidgetTester tester, Widget chips) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: chips)));
  }

  group('AppDayChips — anatomía', () {
    testWidgets('renderiza los 7 días L M X J V S D en orden visual', (
      tester,
    ) async {
      await pumpChips(
        tester,
        AppDayChips(selected: const <int>{}, onChanged: (_) {}),
      );
      for (final label in <String>['L', 'M', 'X', 'J', 'V', 'S', 'D']) {
        expect(find.text(label), findsOneWidget);
      }
      // L (lunes) queda a la izquierda de D (domingo): orden lunes-primero.
      expect(
        tester.getTopLeft(find.text('L')).dx,
        lessThan(tester.getTopLeft(find.text('D')).dx),
      );
    });

    testWidgets('cada día ofrece un blanco táctil de al menos 44x44', (
      tester,
    ) async {
      await pumpChips(
        tester,
        AppDayChips(selected: const <int>{}, onChanged: (_) {}),
      );
      for (var day = 0; day <= 6; day++) {
        final size = tester.getSize(find.byKey(Key('app_day_chips.day.$day')));
        expect(size.width, greaterThanOrEqualTo(44.0), reason: 'día $day');
        expect(size.height, greaterThanOrEqualTo(44.0), reason: 'día $day');
      }
    });

    testWidgets('keyPrefix deriva las keys de cada día', (tester) async {
      await pumpChips(
        tester,
        AppDayChips(
          keyPrefix: 'ventana.0',
          selected: const <int>{},
          onChanged: (_) {},
        ),
      );
      expect(find.byKey(const Key('ventana.0.day.0')), findsOneWidget);
      expect(find.byKey(const Key('ventana.0.day.6')), findsOneWidget);
    });
  });

  group('AppDayChips — estados visuales', () {
    Container dayContainer(WidgetTester tester, int day) {
      return tester.widget<Container>(
        find.descendant(
          of: find.byKey(Key('app_day_chips.day.$day')),
          matching: find.byType(Container),
        ),
      );
    }

    testWidgets(
      'día no seleccionado: fondo transparente, borde divider, label text2',
      (tester) async {
        await pumpChips(
          tester,
          AppDayChips(selected: const <int>{}, onChanged: (_) {}),
        );
        final d = dayContainer(tester, 0).decoration! as BoxDecoration;
        expect(d.color, Colors.transparent);
        expect(d.border?.top.color, AppTokens.divider);
        final label = tester.widget<Text>(find.text('L'));
        expect(label.style?.color, AppTokens.text2);
      },
    );

    testWidgets(
      'día seleccionado: tinte primary@16%, borde y label primary — sin fill '
      'pleno de CTA',
      (tester) async {
        await pumpChips(
          tester,
          AppDayChips(selected: const <int>{0}, onChanged: (_) {}),
        );
        final d = dayContainer(tester, 0).decoration! as BoxDecoration;
        expect(d.color, AppTokens.primary.withValues(alpha: 0.16));
        expect(d.border?.top.color, AppTokens.primary);
        final label = tester.widget<Text>(find.text('L'));
        expect(label.style?.color, AppTokens.primary);
      },
    );

    testWidgets('deshabilitado (onChanged null): opacity 0.4', (tester) async {
      await pumpChips(
        tester,
        const AppDayChips(selected: <int>{0}, onChanged: null),
      );
      final opacities = tester.widgetList<Opacity>(
        find.descendant(
          of: find.byType(AppDayChips),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacities.length, 7);
      for (final o in opacities) {
        expect(o.opacity, 0.4);
      }
    });
  });

  group('AppDayChips — interacción', () {
    testWidgets('tap en día no seleccionado emite el set con el día añadido', (
      tester,
    ) async {
      Set<int>? received;
      await pumpChips(
        tester,
        AppDayChips(
          selected: const <int>{0, 4},
          onChanged: (s) => received = s,
        ),
      );
      await tester.tap(find.byKey(const Key('app_day_chips.day.2')));
      expect(received, <int>{0, 2, 4});
    });

    testWidgets('tap en día seleccionado emite el set con el día quitado', (
      tester,
    ) async {
      Set<int>? received;
      await pumpChips(
        tester,
        AppDayChips(
          selected: const <int>{0, 4},
          onChanged: (s) => received = s,
        ),
      );
      await tester.tap(find.byKey(const Key('app_day_chips.day.4')));
      expect(received, <int>{0});
    });

    testWidgets('el set emitido es una copia: no muta el set de entrada', (
      tester,
    ) async {
      final input = <int>{0};
      Set<int>? received;
      await pumpChips(
        tester,
        AppDayChips(selected: input, onChanged: (s) => received = s),
      );
      await tester.tap(find.byKey(const Key('app_day_chips.day.3')));
      expect(received, <int>{0, 3});
      expect(input, <int>{0});
    });

    testWidgets('deshabilitado: el tap no emite nada', (tester) async {
      // onChanged null bloquea el gesto; el widget queda inerte.
      await pumpChips(
        tester,
        const AppDayChips(selected: <int>{}, onChanged: null),
      );
      await tester.tap(
        find.byKey(const Key('app_day_chips.day.0')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppDayChips — semántica', () {
    testWidgets('cada día expone botón con nombre completo y estado selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChips(
        tester,
        AppDayChips(selected: const <int>{2}, onChanged: (_) {}),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('app_day_chips.day.2'))),
        isSemantics(
          isButton: true,
          isSelected: true,
          label: 'Miércoles',
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('app_day_chips.day.6'))),
        isSemantics(isButton: true, isSelected: false, label: 'Domingo'),
      );
      handle.dispose();
    });
  });
}
