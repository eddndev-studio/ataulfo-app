import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/ai_catalog/presentation/widgets/ai_config_stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('editable: el trailing es un chevron de selector, no un lápiz', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AiConfigStatTile(
          tileKey: const Key('t'),
          label: 'Modelo',
          value: 'gemini-3.1-pro',
          onTap: () {},
        ),
      ),
    );

    // Abre un selector en sheet: el affordance es el mismo chevron que el
    // AppSelectField cerrado, no el lápiz de "editar en sitio".
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('solo-lectura: sin chevron y con la nota "Fija del modelo"', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AiConfigStatTile(
          tileKey: Key('t'),
          label: 'Temperatura',
          value: '1.0',
          note: 'Fija del modelo',
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Fija del modelo'), findsOneWidget);
  });

  testWidgets('tocar el tile editable dispara onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AiConfigStatTile(
          tileKey: const Key('t'),
          label: 'Modelo',
          value: 'gemini-3.1-pro',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('t')));
    expect(tapped, isTrue);
  });
}
