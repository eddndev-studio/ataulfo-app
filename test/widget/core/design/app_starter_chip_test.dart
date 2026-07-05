import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_starter_chip.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, Widget chip) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: chip)),
      ),
    );
  }

  Container chipContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppStarterChip),
        matching: find.byType(Container),
      ),
    );
  }

  testWidgets('renderiza el label', (tester) async {
    await pumpChip(
      tester,
      AppStarterChip(label: 'Muéstrame el prompt', onTap: () {}),
    );
    expect(find.text('Muéstrame el prompt'), findsOneWidget);
  });

  testWidgets('cápsula con borde hairline (divider) y radio pill', (
    tester,
  ) async {
    await pumpChip(tester, AppStarterChip(label: 'x', onTap: () {}));
    final d = chipContainer(tester).decoration as BoxDecoration;
    expect(d.border?.top.color, AppTokens.divider);
    expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusPill));
    // Sin fill: la cápsula es un contorno, no un CTA.
    expect(d.color, isNull);
  });

  testWidgets('ícono por defecto auto_awesome tintado en primary', (
    tester,
  ) async {
    await pumpChip(tester, AppStarterChip(label: 'x', onTap: () {}));
    final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
    expect(icon.color, AppTokens.primary);
  });

  testWidgets('acepta un ícono propio', (tester) async {
    await pumpChip(
      tester,
      AppStarterChip(
        label: 'x',
        icon: Icons.pause_circle_outline,
        onTap: () {},
      ),
    );
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
  });

  testWidgets('el tap dispara onTap (semántica de prefill)', (tester) async {
    var taps = 0;
    await pumpChip(tester, AppStarterChip(label: 'x', onTap: () => taps++));
    await tester.tap(find.byType(AppStarterChip));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
