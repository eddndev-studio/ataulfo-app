import 'package:ataulfo/core/design/widgets/reasoning_disclosure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('colapsado muestra "Razonamiento"; al expandir, el texto', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ReasoningDisclosure(
          reasoning: 'el doc dice que abrimos 9-18',
          keyId: 'm1',
        ),
      ),
    );
    expect(find.text('Razonamiento'), findsOneWidget);
    // Colapsado: el razonamiento no se ve.
    expect(find.textContaining('abrimos 9-18'), findsNothing);

    await tester.tap(find.text('Razonamiento'));
    await tester.pumpAndSettle();

    expect(find.textContaining('abrimos 9-18'), findsOneWidget);
  });
}
