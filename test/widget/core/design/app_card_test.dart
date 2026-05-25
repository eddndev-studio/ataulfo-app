import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
  }

  group('AppCard — rendering', () {
    testWidgets('renderiza el child arbitrario', (tester) async {
      await pumpCard(
        tester,
        const AppCard(child: Text('hola', key: Key('child'))),
      );
      expect(find.byKey(const Key('child')), findsOneWidget);
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('fondo surface2 y radio card', (tester) async {
      await pumpCard(
        tester,
        const AppCard(child: SizedBox(width: 100, height: 100)),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTokens.surface2);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppTokens.radiusCard),
      );
    });

    testWidgets('padding default = AppTokens.cardPadding (20)', (tester) async {
      await pumpCard(tester, const AppCard(child: SizedBox.shrink()));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ),
      );
      expect(container.padding, const EdgeInsets.all(AppTokens.cardPadding));
    });

    testWidgets('padding override por prop', (tester) async {
      await pumpCard(
        tester,
        const AppCard(padding: 0, child: SizedBox.shrink()),
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ),
      );
      expect(container.padding, EdgeInsets.zero);
    });
  });

  group('AppCard — interacción', () {
    testWidgets('sin onTap: no es tappable (no hay InkWell ancestro)', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const AppCard(child: SizedBox(width: 100, height: 100)),
      );
      // InkWell siempre se monta para mantener la forma, pero su onTap es
      // null y, por tanto, no captura taps que disparen efecto.
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('con onTap: tap dispara callback', (tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        AppCard(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 100),
        ),
      );
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
