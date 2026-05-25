import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppDesignTheme.dark(), home: const SplashPage()),
    );
  }

  testWidgets('SplashPage muestra el spinner', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SplashPage usa AppTokens.bgBase como fondo del Scaffold', (
    tester,
  ) async {
    await pump(tester);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final effective =
        scaffold.backgroundColor ?? Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;
    expect(effective, AppTokens.bgBase);
  });

  testWidgets('spinner pintado con AppTokens.primary', (tester) async {
    await pump(tester);

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });
}
