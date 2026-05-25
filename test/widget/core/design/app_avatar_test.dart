import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_avatar.dart';

void main() {
  Future<void> pumpAvatar(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
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
    testWidgets('container circular con surface3', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a'));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppAvatar),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppTokens.surface3);
      expect(decoration.shape, BoxShape.circle);
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
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppAvatar),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });

    testWidgets('size custom respeta el parámetro', (tester) async {
      await pumpAvatar(tester, const AppAvatar(name: 'a', size: 64));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppAvatar),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 64);
    });
  });
}
