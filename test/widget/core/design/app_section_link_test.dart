import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_entity_icon.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_section_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('pinta glifo, título, caption y chevron; tap dispara onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AppSectionLink(
          rowKey: const Key('x.link'),
          icon: Icons.chat_outlined,
          title: 'Conversaciones',
          caption: 'Bandeja del bot',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.byType(AppEntityIcon), findsOneWidget);
    expect(find.text('Conversaciones'), findsOneWidget);
    expect(find.text('Bandeja del bot'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byKey(const Key('x.link')));
    expect(taps, 1);
  });

  testWidgets('count > 0 acompaña al título como pill', (tester) async {
    await tester.pumpWidget(
      host(
        AppSectionLink(
          rowKey: const Key('x.link'),
          icon: Icons.account_tree_outlined,
          title: 'Flujos',
          count: 7,
          onTap: () {},
        ),
      ),
    );

    expect(find.widgetWithText(AppPill, '7'), findsOneWidget);
  });

  testWidgets('título largo en ancho angosto ellipsa sin overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 280,
          child: AppSectionLink(
            rowKey: const Key('x.link'),
            icon: Icons.link,
            title: 'Vínculos con etiquetas internas de la organización',
            count: 12,
            caption: 'Una caption igualmente larga que debe ellipsar bien',
            onTap: () {},
          ),
        ),
      ),
    );

    // Un Row sin Flexible revienta con RenderFlex overflow; el título debe
    // ceder espacio (ellipsis) y dejar la pill de count visible.
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppPill, '12'), findsOneWidget);
  });

  testWidgets('count 0 o null van sin pill (no repetir el vacío)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: <Widget>[
            AppSectionLink(
              rowKey: const Key('a'),
              icon: Icons.data_object,
              title: 'Variables',
              count: 0,
              onTap: () {},
            ),
            AppSectionLink(
              rowKey: const Key('b'),
              icon: Icons.build_outlined,
              title: 'Mantenimiento',
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppPill), findsNothing);
  });
}
