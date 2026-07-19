import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_text_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('acción primaria dispara el callback y conserva 48 px', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      AppTextAction(label: 'Reintentar', onPressed: () => taps++),
    );

    await tester.tap(find.text('Reintentar'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(AppTextAction)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.widget<Text>(find.text('Reintentar')).style?.color,
      AppTokens.primary,
    );
  });

  testWidgets('tonos neutral y danger usan tokens, no defaults Material', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextAction(
            label: 'Cancelar',
            tone: AppTextActionTone.neutral,
            onPressed: () {},
          ),
          AppTextAction(
            label: 'Descartar',
            tone: AppTextActionTone.danger,
            onPressed: () {},
          ),
        ],
      ),
    );

    expect(
      tester.widget<Text>(find.text('Cancelar')).style?.color,
      AppTokens.text2,
    );
    expect(
      tester.widget<Text>(find.text('Descartar')).style?.color,
      AppTokens.danger,
    );
  });

  testWidgets('onPressed null queda deshabilitada', (tester) async {
    await pump(
      tester,
      const AppTextAction(label: 'No disponible', onPressed: null),
    );

    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });
}
