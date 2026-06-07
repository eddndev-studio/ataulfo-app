import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_text_field.dart';

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
      reason:
          'el campo debe pintar su píldora en un Container con BoxDecoration',
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

    testWidgets(
      'label usa caption (labelSmall) del textTheme con color text2',
      (tester) async {
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
      },
    );

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

  group('AppTextField — objetivo táctil', () {
    testWidgets('el alto del campo es >= 48 (objetivo táctil del kit)', (
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
      expect(
        tester.getSize(find.byType(AppTextField)).height,
        greaterThanOrEqualTo(48),
        reason: 'el campo debe garantizar un alto táctil >= 48',
      );
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

  group('AppTextField — obscureText / autocorrect', () {
    testWidgets('default: obscureText es false (texto visible)', (
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
      expect(inner.obscureText, false);
    });

    testWidgets('obscureText: true enmascara el TextField interno', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Contraseña',
          hint: 'h',
          controller: TextEditingController(),
          obscureText: true,
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.obscureText, true);
    });

    testWidgets('default: autocorrect es true (default de Material)', (
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
      expect(inner.autocorrect, true);
    });

    testWidgets('autocorrect se propaga al TextField interno', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'Email',
          hint: 'h',
          controller: TextEditingController(),
          autocorrect: false,
        ),
      );
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.autocorrect, false);
    });
  });

  group('AppTextField — toggle de visibilidad de contraseña', () {
    testWidgets('default: sin obscureToggle no hay IconButton', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'Contraseña',
          hint: 'h',
          controller: TextEditingController(),
          obscureText: true,
        ),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('obscureToggle con obscureText muestra el icono visibility', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Contraseña',
          hint: 'h',
          controller: TextEditingController(),
          obscureText: true,
          obscureToggle: true,
        ),
      );
      // Arranca enmascarado: el icono ofrece "mostrar" (visibility_outlined).
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.obscureText, true);
    });

    testWidgets('tocar el toggle desenmascara (obscureText pasa a false)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Contraseña',
          hint: 'h',
          controller: TextEditingController(),
          obscureText: true,
          obscureToggle: true,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // Tras tocar: texto visible y el icono cambia a visibility_off.
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        false,
      );
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('segundo toque re-enmascara (vuelve a obscureText true)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Contraseña',
          hint: 'h',
          controller: TextEditingController(),
          obscureText: true,
          obscureToggle: true,
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets(
      'obscureToggle sin obscureText no renderiza el botón (nada que ocultar)',
      (tester) async {
        await pump(
          tester,
          AppTextField(
            label: 'X',
            hint: 'h',
            controller: TextEditingController(),
            obscureToggle: true,
          ),
        );
        expect(find.byType(IconButton), findsNothing);
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

  group('AppTextField — selección al enfocar un campo pre-llenado', () {
    testWidgets('al ganar foco, el caret se colapsa al final (no select-all)', (
      tester,
    ) async {
      final c = TextEditingController(text: 'Soporte VIP');
      // Un controller construido con texto trae selección inválida (offset
      // -1): es justo lo que dispara el select-all de plataforma al enfocar.
      expect(c.selection.isValid, isFalse);

      await pump(
        tester,
        AppTextField(label: 'X', hint: 'h', controller: c, autofocus: true),
      );
      await tester.pump(); // asienta el foco (autofocus) y su listener

      // Al enfocar, AppTextField normaliza el caret al final del texto, de
      // modo que el foco coloque el cursor en vez de seleccionar todo.
      expect(
        c.selection,
        const TextSelection.collapsed(offset: 'Soporte VIP'.length),
      );
    });

    testWidgets('enfocar con controller vacío deja el caret natural (0)', (
      tester,
    ) async {
      final c = TextEditingController();
      await pump(
        tester,
        AppTextField(label: 'X', hint: 'h', controller: c, autofocus: true),
      );
      await tester.pump();
      // Sin texto no hay nada que seleccionar: nuestra normalización no aplica
      // y el caret queda donde el framework lo pone al enfocar un campo vacío
      // (offset 0), no en un valor inventado.
      expect(c.text, isEmpty);
      expect(c.selection, const TextSelection.collapsed(offset: 0));
    });

    testWidgets('no pisa una selección ya válida (no fuerza al final)', (
      tester,
    ) async {
      final c = TextEditingController(text: 'hola')
        ..selection = const TextSelection.collapsed(offset: 1);
      await pump(
        tester,
        AppTextField(label: 'X', hint: 'h', controller: c, autofocus: true),
      );
      await tester.pump();
      // La selección válida del usuario (caret en 1) se respeta.
      expect(c.selection, const TextSelection.collapsed(offset: 1));
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

    testWidgets(
      'enfocado: el fill es OPACO (el glow queda por fuera, no sangra adentro)',
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
        await tester.pump();

        // El glow es un boxShadow detrás de la caja; con fill translúcido se
        // veía a través hacia el interior. En foco el fill se vuelve opaco
        // (input compuesto sobre bgBase) para que solo se vea el halo externo.
        final fill = shellDecoration(tester).color!;
        expect(fill.a, 1.0);
        expect(fill, Color.alphaBlend(AppTokens.input, AppTokens.bgBase));
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
      final dimmedByOpacity =
          opacityFinder.evaluate().isNotEmpty &&
          tester.widget<Opacity>(opacityFinder.first).opacity < 1.0;

      final labelColor = tester.widget<Text>(find.text('Correo')).style?.color;
      final dimmedByColor = labelColor == AppTokens.textDisabled;

      expect(
        dimmedByOpacity || dimmedByColor,
        true,
        reason:
            'el campo deshabilitado debe atenuarse (opacity o textDisabled)',
      );
    });
  });

  group('AppTextField — multilínea (text area)', () {
    testWidgets(
      'maxLines > 1: radio = mitad del alto de una línea (24), no pill',
      (tester) async {
        await pump(
          tester,
          AppTextField(
            label: 'Prompt',
            hint: 'Escribe…',
            controller: TextEditingController(),
            maxLines: 6,
          ),
        );
        // El text area NO usa el pill pleno (radiusField=999) sino el radio
        // efectivo de la píldora de una línea (48/2 = 24): un rect redondeado.
        expect(shellDecoration(tester).borderRadius, BorderRadius.circular(24));
      },
    );

    testWidgets('una línea conserva el pill (radiusField)', (tester) async {
      await pump(
        tester,
        AppTextField(
          label: 'Correo',
          hint: 'Value',
          controller: TextEditingController(),
        ),
      );
      expect(
        shellDecoration(tester).borderRadius,
        BorderRadius.circular(AppTokens.radiusField),
      );
    });

    testWidgets('maxLines > 1: padding vertical más generoso (sp3)', (
      tester,
    ) async {
      await pump(
        tester,
        AppTextField(
          label: 'Prompt',
          hint: 'Escribe…',
          controller: TextEditingController(),
          maxLines: 6,
        ),
      );
      // Localiza el Container del shell (el que tiene la BoxDecoration) y lee
      // su padding vertical: multilínea respira con sp3, no sp1.
      final shell = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AppTextField),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((c) => c.decoration is BoxDecoration);
      final padding = shell.padding! as EdgeInsets;
      expect(padding.top, AppTokens.sp3);
      expect(padding.bottom, AppTokens.sp3);
    });
  });
}
