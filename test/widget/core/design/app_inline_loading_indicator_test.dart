import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_inline_loading_indicator.dart';

void main() {
  testWidgets('AppInlineLoadingIndicator conserva una huella compacta', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppInlineLoadingIndicator(size: 16)),
      ),
    );

    expect(
      tester.getSize(find.byType(AppInlineLoadingIndicator)),
      const Size(16, 16),
    );
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.strokeWidth, 2);
    expect(spinner.valueColor?.value, AppTokens.primary);
  });
}
