import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_danger_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('pinta hairline, heading titleMedium, caption y la acción', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppDangerZone(
          caption: 'Esto no se puede deshacer.',
          actions: <Widget>[
            AppButton.danger(
              key: const Key('x.delete'),
              label: 'Eliminar',
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    // El hairline separa la zona del resto de la página.
    expect(
      find.descendant(
        of: find.byType(AppDangerZone),
        matching: find.byType(Divider),
      ),
      findsOneWidget,
    );
    final context = tester.element(find.byType(AppDangerZone));
    final heading = tester.widget<Text>(find.text('Zona peligrosa'));
    expect(heading.style, Theme.of(context).textTheme.titleMedium);
    final caption = tester.widget<Text>(
      find.text('Esto no se puede deshacer.'),
    );
    expect(caption.style?.color, AppTokens.text2);
    expect(find.byKey(const Key('x.delete')), findsOneWidget);
  });

  testWidgets('apila varias acciones en orden', (tester) async {
    await tester.pumpWidget(
      host(
        AppDangerZone(
          caption: 'Operaciones irreversibles.',
          actions: <Widget>[
            AppButton.danger(
              key: const Key('x.a'),
              label: 'Acción A',
              fullWidth: true,
              onPressed: () {},
            ),
            AppButton.danger(
              key: const Key('x.b'),
              label: 'Acción B',
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('x.a')), findsOneWidget);
    expect(find.byKey(const Key('x.b')), findsOneWidget);
    final a = tester.getTopLeft(find.byKey(const Key('x.a')));
    final b = tester.getTopLeft(find.byKey(const Key('x.b')));
    expect(a.dy, lessThan(b.dy));
  });
}
