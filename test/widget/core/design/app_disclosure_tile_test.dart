import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_disclosure_tile.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('colapsado por defecto: título e ícono visibles, cuerpo oculto', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppDisclosureTile(
          icon: Icons.psychology_outlined,
          title: 'Detalles',
          child: Text('cuerpo secreto'),
        ),
      ),
    );
    expect(find.text('Detalles'), findsOneWidget);
    expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    expect(find.text('cuerpo secreto'), findsNothing);
  });

  testWidgets('al tocar el título expande y revela el cuerpo', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppDisclosureTile(
          icon: Icons.info_outline,
          title: 'Detalles',
          child: Text('cuerpo secreto'),
        ),
      ),
    );
    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();
    expect(find.text('cuerpo secreto'), findsOneWidget);
  });

  testWidgets('initiallyExpanded: el cuerpo se ve desde el inicio', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppDisclosureTile(
          icon: Icons.info_outline,
          title: 'Detalles',
          initiallyExpanded: true,
          child: Text('cuerpo secreto'),
        ),
      ),
    );
    expect(find.text('cuerpo secreto'), findsOneWidget);
  });

  testWidgets('la superficie es surface2 con radio sm', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppDisclosureTile(
          icon: Icons.info_outline,
          title: 'Detalles',
          child: Text('x'),
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppDisclosureTile),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppTokens.surface2);
  });
}
