import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_code_field.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget field) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(body: field),
      ),
    );
  }

  group('AppCodeField — estructura', () {
    testWidgets('pinta `length` casillas (default 6)', (tester) async {
      await pump(tester, AppCodeField(controller: TextEditingController()));

      expect(find.byKey(const Key('app_code_field.box.0')), findsOneWidget);
      expect(find.byKey(const Key('app_code_field.box.5')), findsOneWidget);
      expect(find.byKey(const Key('app_code_field.box.6')), findsNothing);
    });

    testWidgets('respeta un `length` distinto', (tester) async {
      await pump(
        tester,
        AppCodeField(controller: TextEditingController(), length: 4),
      );

      expect(find.byKey(const Key('app_code_field.box.3')), findsOneWidget);
      expect(find.byKey(const Key('app_code_field.box.4')), findsNothing);
    });

    testWidgets('un solo campo de captura (EditableText) para el input', (
      tester,
    ) async {
      await pump(tester, AppCodeField(controller: TextEditingController()));

      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('el campo de captura pide teclado numérico y OTP autofill', (
      tester,
    ) async {
      await pump(tester, AppCodeField(controller: TextEditingController()));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.keyboardType, TextInputType.number);
      expect(tf.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets('permite pegar (selección interactiva no suprimida)', (
      tester,
    ) async {
      // Los OTP llegan por correo, no por SMS: el autofill no basta, el operador
      // pega el código. Suprimir la selección interactiva mataría el toolbar de
      // "Pegar" (invisible pero funcional bajo el Opacity(0)).
      await pump(tester, AppCodeField(controller: TextEditingController()));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enableInteractiveSelection, isNot(false));
    });
  });

  group('AppCodeField — input', () {
    testWidgets('pinta cada dígito escrito en su casilla', (tester) async {
      final controller = TextEditingController();
      await pump(tester, AppCodeField(controller: controller));

      await tester.enterText(find.byType(AppCodeField), '12');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(controller.text, '12');
    });

    testWidgets('filtra lo no numérico (digitsOnly)', (tester) async {
      final controller = TextEditingController();
      await pump(tester, AppCodeField(controller: controller));

      await tester.enterText(find.byType(AppCodeField), 'a1b2c3');
      await tester.pump();

      expect(controller.text, '123');
    });

    testWidgets('no acepta más de `length` dígitos', (tester) async {
      final controller = TextEditingController();
      await pump(tester, AppCodeField(controller: controller, length: 6));

      await tester.enterText(find.byType(AppCodeField), '1234567890');
      await tester.pump();

      expect(controller.text, '123456');
    });

    testWidgets('onCompleted se dispara al llenar la longitud', (tester) async {
      String? completed;
      final controller = TextEditingController();
      await pump(
        tester,
        AppCodeField(
          controller: controller,
          onCompleted: (code) => completed = code,
        ),
      );

      await tester.enterText(find.byType(AppCodeField), '12345');
      await tester.pump();
      expect(completed, isNull);

      await tester.enterText(find.byType(AppCodeField), '123456');
      await tester.pump();
      expect(completed, '123456');
    });

    testWidgets('tocar el campo enfoca la captura', (tester) async {
      await pump(tester, AppCodeField(controller: TextEditingController()));

      await tester.tap(find.byType(AppCodeField));
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    });
  });

  group('AppCodeField — estados', () {
    testWidgets('deshabilitado no acepta input', (tester) async {
      final controller = TextEditingController();
      await pump(tester, AppCodeField(controller: controller, enabled: false));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
    });

    testWidgets('la casilla activa resalta con el color primario', (
      tester,
    ) async {
      final controller = TextEditingController();
      await pump(tester, AppCodeField(controller: controller));

      // Sin dígitos la casilla activa es la primera. Al enfocar debe pintar el
      // borde primario, mismo lenguaje visual del foco de AppTextField.
      await tester.tap(find.byType(AppCodeField));
      await tester.pump();

      final box = tester.widget<Container>(
        find.byKey(const Key('app_code_field.box.0')),
      );
      final decoration = box.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, AppTokens.primary);
    });
  });
}
