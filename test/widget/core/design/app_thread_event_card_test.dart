import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_thread_event_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  BoxDecoration cardDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppThreadEventCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('AppThreadEventCard — decoración', () {
    testWidgets('surface2 + borde divider + radio pill por defecto', (
      tester,
    ) async {
      await pump(tester, const AppThreadEventCard(child: Text('evento')));
      final d = cardDecoration(tester);
      expect(d.color, AppTokens.surface2);
      expect(d.border?.top.color, AppTokens.divider);
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusPill));
    });

    testWidgets('error tiñe el borde en danger', (tester) async {
      await pump(
        tester,
        const AppThreadEventCard(error: true, child: Text('x')),
      );
      expect(cardDecoration(tester).border?.top.color, AppTokens.danger);
    });

    testWidgets('expanded usa radio card', (tester) async {
      await pump(
        tester,
        const AppThreadEventCard(expanded: true, child: Text('x')),
      );
      expect(
        cardDecoration(tester).borderRadius,
        BorderRadius.circular(AppTokens.radiusCard),
      );
    });
  });

  group('AppThreadEventCard — interacción', () {
    testWidgets('onTap se dispara al tocar la tarjeta', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppThreadEventCard(onTap: () => taps++, child: const Text('x')),
      );
      await tester.tap(find.byType(AppThreadEventCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('sin onTap no monta GestureDetector propio', (tester) async {
      await pump(tester, const AppThreadEventCard(child: Text('x')));
      expect(
        find.descendant(
          of: find.byType(AppThreadEventCard),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('AppThreadEventHeader', () {
    testWidgets('ícono en primary y label por defecto', (tester) async {
      await pump(
        tester,
        const AppThreadEventHeader(
          icon: Icons.edit_note,
          label: 'Prompt actualizado',
        ),
      );
      expect(find.text('Prompt actualizado'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.edit_note));
      expect(icon.color, AppTokens.primary);
    });

    testWidgets('error tiñe el ícono en danger', (tester) async {
      await pump(
        tester,
        const AppThreadEventHeader(
          icon: Icons.warning_amber_rounded,
          label: 'Falló',
          error: true,
        ),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(icon.color, AppTokens.danger);
    });

    testWidgets('showChevron monta el chevron con su key y dirección', (
      tester,
    ) async {
      await pump(
        tester,
        const AppThreadEventHeader(
          icon: Icons.account_tree_outlined,
          label: 'Flujo',
          showChevron: true,
          expanded: true,
          chevronKey: Key('ev.chevron'),
        ),
      );
      expect(find.byKey(const Key('ev.chevron')), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('sin showChevron no hay chevron', (tester) async {
      await pump(
        tester,
        const AppThreadEventHeader(icon: Icons.bolt_outlined, label: 'Usó x'),
      );
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });
  });
}
