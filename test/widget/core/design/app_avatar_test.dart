import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_avatar.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  }

  // El decorado vive en el Container raíz del avatar (descendiente directo
  // del widget). Centralizamos el lookup como en el resto de los tests del kit.
  Container rootContainer(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppAvatar),
        matching: find.byType(Container),
      ),
    );
  }

  group('AppAvatar — inicial', () {
    testWidgets('toma la primera letra en uppercase', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'soporte'));
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('trim previo a tomar la inicial', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: '  ventas'));
      expect(find.text('V'), findsOneWidget);
    });

    testWidgets("vacío o solo espacios cae a '?'", (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: '   '));
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('AppAvatar — estilo', () {
    testWidgets('container circular', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('interior en superficie oscura del kit (surface2/surface3)', (
      tester,
    ) async {
      // El anillo amarillo es el protagonista; el relleno se mantiene en una
      // superficie oscura para que la inicial y el borde resalten. El kit
      // admite tanto surface2 como surface3 para este relleno.
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(
        decoration.color,
        anyOf(AppTokens.surface2, AppTokens.surface3),
      );
    });

    testWidgets('anillo: borde primary alrededor del avatar', (tester) async {
      // Detalle nuevo del re-skin (UserIcon): un anillo amarillo perimetral.
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final decoration = rootContainer(tester).decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border?.top.color, AppTokens.primary);
      expect(decoration.border?.top.width, greaterThan(0));
    });

    testWidgets('label DMSans bodyL/w600 con text1', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final style = tester.widget<Text>(find.text('A')).style;
      expect(style?.fontFamily, AppTokens.fontSans);
      expect(style?.fontSize, AppTokens.bodyLSize);
      expect(style?.fontWeight, FontWeight.w600);
      expect(style?.color, AppTokens.text1);
    });
  });

  group('AppAvatar — tamaño', () {
    testWidgets('default size 40x40', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));
      final container = rootContainer(tester);
      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });

    testWidgets('size custom respeta el parámetro', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a', size: 64));
      final container = rootContainer(tester);
      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 64);
    });
  });
}
