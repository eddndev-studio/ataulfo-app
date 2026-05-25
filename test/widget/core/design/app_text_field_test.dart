import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_text_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget field) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(body: field),
      ),
    );
  }

  group('AppTextField — estructura', () {
    testWidgets('renderiza el label encima del field (no floating)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Nombre',
          hint: 'Ej. Soporte',
          controller: TextEditingController(),
        ),
      );
      // El label es un Text con la copy esperada Y queda por arriba del
      // TextField en el árbol (Column ascendente común).
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('label usa labelSmall del textTheme con color text2', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Nombre',
          hint: 'h',
          controller: TextEditingController(),
        ),
      );
      final style = tester.widget<Text>(find.text('Nombre')).style;
      expect(style?.fontFamily, AppTokens.fontSans);
      expect(style?.fontSize, AppTokens.captionSize);
      expect(style?.color, AppTokens.text2);
    });
  });

  group('AppTextField — input', () {
    testWidgets('escribir propaga al controller', (tester) async {
      final c = TextEditingController();
      await pump(tester, AppTextField(label: 'X', hint: 'h', controller: c));

      await tester.enterText(find.byType(TextField), 'Soporte');
      expect(c.text, 'Soporte');
    });

    testWidgets('onSubmitted propaga el texto al callback', (tester) async {
      String? submitted;
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
          onSubmitted: (v) => submitted = v,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pago');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 'Pago');
    });

    testWidgets('enabled: false bloquea el input (TextField disabled)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
          enabled: false,
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.enabled, false);
    });
  });

  group('AppTextField — estilo del field', () {
    testWidgets('fill surface3 + sin border visible (radio radiusField)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      final deco = inner.decoration!;
      expect(deco.filled, true);
      expect(deco.fillColor, AppTokens.surface3);
      // Borderless = OutlineInputBorder con BorderSide.none.
      final border = deco.enabledBorder as OutlineInputBorder;
      expect(border.borderSide, BorderSide.none);
      expect(border.borderRadius, BorderRadius.circular(AppTokens.radiusField));
    });

    testWidgets('hintStyle en bodyMedium text2 (sin tinte ColorScheme)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'Ej. Algo',
          controller: TextEditingController(),
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.decoration!.hintStyle?.color, AppTokens.text2);
      expect(inner.decoration!.hintStyle?.fontSize, AppTokens.bodyMSize);
    });
  });
}
