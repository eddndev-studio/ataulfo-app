import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_entity_icon.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('pinta glifo destacado (56), título y descripción en una glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppEmptyState(
          icon: Icons.smart_toy_outlined,
          title: 'Aún no tienes bots',
          description: 'Crea tu primer bot.',
        ),
      ),
    );
    expect(find.byType(AppCard), findsOneWidget);
    final glyph = tester.widget<AppEntityIcon>(find.byType(AppEntityIcon));
    expect(glyph.icon, Icons.smart_toy_outlined);
    expect(glyph.highlighted, isTrue);
    expect(glyph.size, 56);
    expect(find.text('Aún no tienes bots'), findsOneWidget);
    expect(find.text('Crea tu primer bot.'), findsOneWidget);
  });

  testWidgets('sin CTA: no monta botón', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppEmptyState(icon: Icons.inbox_outlined, title: 'Vacío')),
    );
    expect(find.byType(AppButton), findsNothing);
  });

  testWidgets('con CTA: monta AppButton.filled y el tap lo dispara', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Vacío',
          ctaLabel: 'Crear',
          onCta: () => taps++,
        ),
      ),
    );
    expect(find.text('Crear'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('ctaIcon fluye al AppButton del CTA', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Vacío',
          ctaLabel: 'Crear',
          ctaIcon: Icons.add,
          onCta: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
