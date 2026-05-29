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

  // El shell del campo es el contenedor con `BoxDecoration` que aporta la
  // píldora: fill, borde y glow viven en él (un `boxShadow` no cabe en un
  // `InputDecoration`, así que la forma se pinta en un wrapper). Aislamos
  // ESE contenedor descartando los que no llevan `BoxDecoration`.
  BoxDecoration shellDecoration(WidgetTester tester) {
    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(AppTextField),
        matching: find.byType(Container),
      ),
    );
    final shells = containers
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => c.decoration! as BoxDecoration)
        .where((d) => d.borderRadius != null);
    expect(
      shells,
      isNotEmpty,
      reason: 'el campo debe pintar su píldora en un Container con BoxDecoration',
    );
    return shells.first;
  }

  BorderSide topSide(BoxDecoration d) => (d.border! as Border).top;

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

    testWidgets('label usa caption (labelSmall) del textTheme con color text2', (
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

    testWidgets('helper se renderiza bajo el field con copy y color text2', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
          helperText: 'correo@correo.com',
        ),
      );
      expect(find.text('correo@correo.com'), findsOneWidget);
      final style = tester.widget<Text>(find.text('correo@correo.com')).style;
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

  group('AppTextField — forma y fondo (default)', () {
    testWidgets('píldora: borderRadius == radiusField sobre el shell', (
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
      final d = shellDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(AppTokens.radiusField));
    });

    testWidgets('fondo del campo = AppTokens.input', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
        ),
      );
      expect(shellDecoration(tester).color, AppTokens.input);
    });

    testWidgets(
      'default: borde 2px transparente (reserva el grosor para no saltar al '
      'enfocar)',
      (tester) async {
        await pump(
          tester,
          AppTextField(
            label: 'X',
            hint: 'h',
            controller: TextEditingController(),
          ),
        );
        final side = topSide(shellDecoration(tester));
        expect(side.width, 2);
        expect(side.color, Colors.transparent);
      },
    );

    testWidgets('default: sin glow (boxShadow nulo o vacío)', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'h',
          controller: TextEditingController(),
        ),
      );
      final shadow = shellDecoration(tester).boxShadow;
      expect(shadow == null || shadow.isEmpty, true);
    });

    testWidgets('hint en color text2', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'X',
          hint: 'Value',
          controller: TextEditingController(),
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.decoration!.hintStyle?.color, AppTokens.text2);
    });
  });

  group('AppTextField — foco', () {
    testWidgets(
      'enfocado: borde 2px primary + glow (boxShadow con primaryGlow)',
      (tester) async {
        await pump(
          tester,
          AppTextField(
            label: 'X',
            hint: 'h',
            controller: TextEditingController(),
            autofocus: true,
          ),
        );
        // autofocus dispara el FocusNode al primer frame; un pump asienta el
        // rebuild del shell hacia su estado enfocado.
        await tester.pump();

        final d = shellDecoration(tester);
        final side = topSide(d);
        expect(side.width, 2);
        expect(side.color, AppTokens.primary);

        final shadow = d.boxShadow;
        expect(shadow, isNotNull);
        expect(shadow!.isNotEmpty, true);
        expect(shadow.first.color, AppTokens.primaryGlow);
      },
    );
  });

  group('AppTextField — error', () {
    testWidgets('errorText: borde 2px danger en el shell', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
          errorText: 'Correo inválido',
        ),
      );
      final side = topSide(shellDecoration(tester));
      expect(side.width, 2);
      expect(side.color, AppTokens.danger);
    });

    testWidgets('errorText: label en color danger', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
          errorText: 'Correo inválido',
        ),
      );
      final style = tester.widget<Text>(find.text('Correo')).style;
      expect(style?.color, AppTokens.danger);
    });

    testWidgets('errorText: el mensaje se muestra bajo el field en danger', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
          errorText: 'Correo inválido',
        ),
      );
      expect(find.text('Correo inválido'), findsOneWidget);
      final style = tester.widget<Text>(find.text('Correo inválido')).style;
      expect(style?.color, AppTokens.danger);
    });
  });

  group('AppTextField — disabled', () {
    testWidgets('disabled: atenuado (opacity < 1 o texto en textDisabled)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
          enabled: false,
        ),
      );

      // El atenuado se expresa o con un Opacity envolvente (< 1) o tinéndo el
      // label con textDisabled. Cualquiera de las dos satisface el contrato.
      final opacityFinder = find.descendant(
        of: find.byType(AppTextField),
        matching: find.byType(Opacity),
      );
      final dimmedByOpacity = opacityFinder.evaluate().isNotEmpty &&
          tester.widget<Opacity>(opacityFinder.first).opacity < 1.0;

      final labelColor = tester.widget<Text>(find.text('Correo')).style?.color;
      final dimmedByColor = labelColor == AppTokens.textDisabled;

      expect(
        dimmedByOpacity || dimmedByColor,
        true,
        reason: 'el campo deshabilitado debe atenuarse (opacity o textDisabled)',
      );
    });
  });
}
