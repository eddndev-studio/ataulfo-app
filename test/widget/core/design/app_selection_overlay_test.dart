import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_selection_overlay.dart';

void main() {
  testWidgets('AppSelectionOverlay usa el estado seleccionado del sistema', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.square(dimension: 96, child: AppSelectionOverlay()),
        ),
      ),
    );

    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(AppSelectionOverlay),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(box.color, AppTokens.primaryGlow);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, AppTokens.primary);
    expect(find.bySemanticsLabel('Seleccionado'), findsOneWidget);
  });
}
