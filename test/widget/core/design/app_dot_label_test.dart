import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_dot_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('AppDotLabel', () {
    testWidgets('pinta el dot del color del estado y el label en text2', (
      tester,
    ) async {
      await pump(
        tester,
        const AppDotLabel(color: AppTokens.success, label: 'Enlazado'),
      );

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('app_dot_label.dot')),
      );
      final d = dot.decoration as BoxDecoration;
      expect(d.color, AppTokens.success);
      expect(d.shape, BoxShape.circle);

      final text = tester.widget<Text>(find.text('Enlazado'));
      expect(text.style?.color, AppTokens.text2);
      final labelStyle = AppDesignTheme.dark().textTheme.labelSmall!;
      expect(text.style?.fontFamily, labelStyle.fontFamily);
      expect(text.style?.fontSize, labelStyle.fontSize);
      expect(text.style?.fontWeight, labelStyle.fontWeight);
      expect(text.style?.letterSpacing, labelStyle.letterSpacing);
    });

    testWidgets('un label largo ellipsa en una línea', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 80,
          child: AppDotLabel(
            color: AppTokens.danger,
            label: 'Un estado larguísimo que no cabe',
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text('Un estado larguísimo que no cabe'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
