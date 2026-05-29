import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_entity_icon.dart';

void main() {
  Future<void> pumpEntityIcon(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  }

  // El decorado vive en el Container raíz del tile (descendiente directo del
  // widget). Centralizamos el lookup como en el resto de los tests del kit.
  Container rootContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppEntityIcon),
        matching: find.byType(Container),
      ),
    );
  }

  group('AppEntityIcon — contenido', () {
    testWidgets('letter: muestra el texto verbatim y no hay ícono', (
      tester,
    ) async {
      // A diferencia del avatar, el EntityIcon no deriva inicial: pinta la
      // letra tal cual la recibe.
      await pumpEntityIcon(tester, const AppEntityIcon(letter: 'A'));
      expect(find.text('A'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('icon: renderiza el ícono y no hay letra', (tester) async {
      await pumpEntityIcon(tester, const AppEntityIcon(icon: Icons.folder));
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('AppEntityIcon — geometría', () {
    testWidgets('cuadrado redondeado: radio radiusSm (8)', (tester) async {
      await pumpEntityIcon(tester, const AppEntityIcon(letter: 'A'));
      final d = rootContainer(tester).decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusSm));
    });

    testWidgets('lado = size: default 44x44', (tester) async {
      await pumpEntityIcon(tester, const AppEntityIcon(letter: 'A'));
      final size = tester.getSize(find.byType(AppEntityIcon));
      expect(size, const Size(44, 44));
    });

    testWidgets('lado = size: respeta el parámetro custom', (tester) async {
      await pumpEntityIcon(
        tester,
        const AppEntityIcon(letter: 'A', size: 64),
      );
      final size = tester.getSize(find.byType(AppEntityIcon));
      expect(size, const Size(64, 64));
    });
  });

  group('AppEntityIcon — relleno', () {
    testWidgets('highlighted false: fondo surface3 (sin gradiente)', (
      tester,
    ) async {
      await pumpEntityIcon(tester, const AppEntityIcon(letter: 'A'));
      final d = rootContainer(tester).decoration as BoxDecoration;
      // El relleno sólido y el gradiente viven en campos distintos del
      // BoxDecoration; el gradiente nulo fuerza al impl a usar color sólido.
      expect(d.color, AppTokens.surface3);
      expect(d.gradient, isNull);
    });

    testWidgets('highlighted true: fondo brandGradient (sin color sólido)', (
      tester,
    ) async {
      await pumpEntityIcon(
        tester,
        const AppEntityIcon(letter: 'A', highlighted: true),
      );
      final d = rootContainer(tester).decoration as BoxDecoration;
      expect(d.gradient, AppTokens.brandGradient);
      expect(d.color, isNull);
    });
  });

  group('AppEntityIcon — color de contenido', () {
    testWidgets('highlighted false: letra en text1', (tester) async {
      await pumpEntityIcon(tester, const AppEntityIcon(letter: 'A'));
      final style = tester.widget<Text>(find.text('A')).style;
      expect(style?.color, AppTokens.text1);
    });

    testWidgets('highlighted true: letra en onPrimary', (tester) async {
      // Regla on-primary: contenido sobre fill cálido va en oscuro, nunca
      // blanco.
      await pumpEntityIcon(
        tester,
        const AppEntityIcon(letter: 'A', highlighted: true),
      );
      final style = tester.widget<Text>(find.text('A')).style;
      expect(style?.color, AppTokens.onPrimary);
    });

    testWidgets('highlighted false: ícono en text1', (tester) async {
      await pumpEntityIcon(tester, const AppEntityIcon(icon: Icons.folder));
      final icon = tester.widget<Icon>(find.byIcon(Icons.folder));
      expect(icon.color, AppTokens.text1);
    });

    testWidgets('highlighted true: ícono en onPrimary', (tester) async {
      await pumpEntityIcon(
        tester,
        const AppEntityIcon(icon: Icons.folder, highlighted: true),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.folder));
      expect(icon.color, AppTokens.onPrimary);
    });
  });
}
