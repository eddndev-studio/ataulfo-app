import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_option_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('pinta el título y dispara onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AppOptionRow(
          key: const Key('row.a'),
          title: 'Opción A',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Opción A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('row.a')));
    expect(tapped, isTrue);
  });

  testWidgets('onTap null deja la fila inerte', (tester) async {
    await tester.pumpWidget(
      host(const AppOptionRow(key: Key('row.a'), title: 'Opción A')),
    );

    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('row.a')),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.onTap, isNull);
  });

  testWidgets(
    'selected muestra el check de marca; sin selección no hay check',
    (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: <Widget>[
              AppOptionRow(
                key: const Key('row.a'),
                title: 'Opción A',
                selected: true,
                selectedIconKey: const Key('row.a.check'),
                onTap: () {},
              ),
              AppOptionRow(key: const Key('row.b'), title: 'B', onTap: () {}),
            ],
          ),
        ),
      );

      final check = tester.widget<Icon>(find.byKey(const Key('row.a.check')));
      expect(check.icon, Icons.check);
      expect(check.color, AppTokens.primary);
      expect(
        find.descendant(
          of: find.byKey(const Key('row.b')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('acepta leading y trailing extra', (tester) async {
    await tester.pumpWidget(
      host(
        AppOptionRow(
          key: const Key('row.a'),
          leading: const Icon(Icons.label_outline, key: Key('row.a.leading')),
          title: 'Opción A',
          trailing: const <Widget>[
            Icon(Icons.image_outlined, key: Key('row.a.badge')),
          ],
          onTap: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('row.a.leading')), findsOneWidget);
    expect(find.byKey(const Key('row.a.badge')), findsOneWidget);
  });

  testWidgets('el título largo se trunca con ellipsis en una línea', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 200,
          child: AppOptionRow(
            key: const Key('row.a'),
            title: 'Un título larguísimo que no cabe en doscientos píxeles',
            onTap: () {},
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(
      find.text('Un título larguísimo que no cabe en doscientos píxeles'),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
