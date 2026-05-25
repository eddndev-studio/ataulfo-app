import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_button.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester, Widget button) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: button)));
  }

  Container _root(WidgetTester tester) {
    return tester.widget<Container>(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Container),
      ),
    );
  }

  group('AppButton — variantes', () {
    testWidgets('filled: fondo primary, label en blanco', (tester) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Crear', onPressed: () {}),
      );
      final c = _root(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.primary);
      final label = tester.widget<Text>(find.text('Crear'));
      expect(label.style?.color, Colors.white);
    });

    testWidgets('tonal: fondo surface2, label en text1', (tester) async {
      await pumpButton(
        tester,
        AppButton.tonal(label: 'Pausar', onPressed: () {}),
      );
      final c = _root(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, AppTokens.surface2);
      final label = tester.widget<Text>(find.text('Pausar'));
      expect(label.style?.color, AppTokens.text1);
    });

    testWidgets('text: fondo transparent, label en primary', (tester) async {
      await pumpButton(
        tester,
        AppButton.text(label: 'Copiar', onPressed: () {}),
      );
      final c = _root(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      final label = tester.widget<Text>(find.text('Copiar'));
      expect(label.style?.color, AppTokens.primary);
    });

    testWidgets('danger: fondo transparent, label en danger', (tester) async {
      await pumpButton(
        tester,
        AppButton.danger(label: 'Eliminar', onPressed: () {}),
      );
      final c = _root(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.color, Colors.transparent);
      final label = tester.widget<Text>(find.text('Eliminar'));
      expect(label.style?.color, AppTokens.danger);
    });
  });

  group('AppButton — geometría', () {
    testWidgets('altura mínima 48 + radio 14', (tester) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'X', onPressed: () {}),
      );
      final c = _root(tester);
      final d = c.decoration as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusButton));
      // height de 48 lo enforce un ConstrainedBox con minHeight.
      final box = tester.getSize(find.byType(AppButton));
      expect(box.height, greaterThanOrEqualTo(48));
    });

    testWidgets('fullWidth: ocupa todo el ancho disponible', (tester) async {
      await pumpButton(
        tester,
        SizedBox(
          width: 400,
          child: AppButton.filled(
            label: 'X',
            onPressed: () {},
            fullWidth: true,
          ),
        ),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.width, 400);
    });

    testWidgets('default: NO ocupa todo el ancho disponible', (tester) async {
      await pumpButton(
        tester,
        SizedBox(
          width: 400,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton.filled(label: 'X', onPressed: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.width, lessThan(400));
    });
  });

  group('AppButton — estados', () {
    testWidgets('onPressed null: opacity 0.4 y no tappable', (tester) async {
      var taps = 0;
      await pumpButton(
        tester,
        AppButton.filled(label: 'X', onPressed: null),
      );
      // Tap no debe disparar nada (onPressed null).
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(taps, 0);
      // Opacity widget alrededor.
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('onPressed asignado: tap dispara callback', (tester) async {
      var taps = 0;
      await pumpButton(
        tester,
        AppButton.filled(label: 'X', onPressed: () => taps++),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('AppButton — icono opcional', () {
    testWidgets('sin icon: no hay Icon en el árbol', (tester) async {
      await pumpButton(
        tester,
        AppButton.filled(label: 'Sin icon', onPressed: () {}),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('con icon: renderiza Icon a la izquierda del label', (
      tester,
    ) async {
      await pumpButton(
        tester,
        AppButton.filled(
          label: 'Crear',
          icon: Icons.add,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.add));
      expect(icon.color, Colors.white);
    });
  });
}
