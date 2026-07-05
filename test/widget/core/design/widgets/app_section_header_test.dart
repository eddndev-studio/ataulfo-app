import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('con caption: título en titleMedium y caption atenuado', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppSectionHeader(
          title: 'Parámetros del motor',
          caption: 'Cada cambio se guarda al momento.',
        ),
      ),
    );

    final titleFinder = find.text('Parámetros del motor');
    final captionFinder = find.text('Cada cambio se guarda al momento.');
    expect(titleFinder, findsOneWidget);
    expect(captionFinder, findsOneWidget);

    final ctx = tester.element(titleFinder);
    expect(
      tester.widget<Text>(titleFinder).style,
      Theme.of(ctx).textTheme.titleMedium,
    );
    expect(tester.widget<Text>(captionFinder).style?.color, AppTokens.text2);
  });

  testWidgets('sin caption: solo el título, sin segundo Text', (tester) async {
    await tester.pumpWidget(host(const AppSectionHeader(title: 'Solo título')));

    expect(find.text('Solo título'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}
