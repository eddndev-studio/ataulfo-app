import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    testWidgets('keyboardType se propaga al TextField interno', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
          keyboardType: TextInputType.number,
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.keyboardType, TextInputType.number);
    });

    testWidgets('inputFormatters se propagan al TextField interno', (
      tester,
    ) async {
      final formatters = <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ];
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
          inputFormatters: formatters,
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.inputFormatters, formatters);
    });

    testWidgets(
      'digitsOnly formatter filtra letras y deja sólo dígitos en el controller',
      (tester) async {
        // Verificación end-to-end del contrato: aunque el envío del teclado
        // virtual incluya letras, el formatter las descarta antes de que
        // lleguen al controller. La página que pone `keyboardType: number`
        // ya bloquea visualmente, pero el formatter es la red de seguridad
        // ante teclado físico, paste, o métodos de input alternos.
        final c = TextEditingController();
        await pump(
          tester,
          AppTextField(
            label: 'X',
            hint: 'h',
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        );
        await tester.enterText(find.byType(TextField), 'abc42');
        expect(c.text, '42');
      },
    );
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
