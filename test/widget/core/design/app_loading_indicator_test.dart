import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('spinner ámbar (valueColor primary), sin label por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppLoadingIndicator()));
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('con label: pinta el texto debajo del spinner', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppLoadingIndicator(label: 'Cargando…')),
    );
    expect(find.text('Cargando…'), findsOneWidget);
  });
}
