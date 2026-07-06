import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/tokens.dart';
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

  testWidgets('inerte por mutación (enabled:false): conserva el chevron, '
      'se atenúa con el idioma disabled del kit y no dispara onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        AiConfigStatTile(
          tileKey: const Key('t'),
          label: 'Modelo',
          value: 'gemini-3.1-pro',
          enabled: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    // La affordance NO parpadea: el chevron sigue; el tile solo se atenúa.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('t')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 0.4);

    await tester.tap(find.byKey(const Key('t')));
    expect(tapped, isFalse);
  });

  group('press-scale (feedback táctil)', () {
    AnimatedScale scaleWidget(WidgetTester tester) =>
        tester.widget<AnimatedScale>(
          find.descendant(
            of: find.byType(AiConfigStatTile),
            matching: find.byType(AnimatedScale),
          ),
        );

    testWidgets('presionado encoge sutil (0.98: superficie grande) y '
        'regresa al soltar', (tester) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('t'))),
      );
      await tester.pump();
      expect(scaleWidget(tester).scale, 0.98);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleWidget(tester).scale, 1.0);
    });

    testWidgets('solo-lectura (onTap null) no encoge', (tester) async {
      await tester.pumpWidget(
        host(
          const AiConfigStatTile(
            tileKey: Key('t'),
            label: 'Temperatura',
            value: '1.0',
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('t'))),
      );
      await tester.pump();
      expect(scaleWidget(tester).scale, 1.0);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('con AppMotion apagado no encoge', (tester) async {
      await tester.pumpWidget(
        AppMotion(
          enabled: false,
          child: host(
            AiConfigStatTile(
              tileKey: const Key('t'),
              label: 'Modelo',
              value: 'gemini-3.1-pro',
              onTap: () {},
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('t'))),
      );
      await tester.pump();
      expect(scaleWidget(tester).scale, 1.0);
      await gesture.up();
      await tester.pump();
    });
  });

  testWidgets('pinta surface3: bloque anidado perceptible sobre una card '
      'surface2', (tester) async {
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

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('t')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration! as BoxDecoration).color, AppTokens.surface3);
  });
}
