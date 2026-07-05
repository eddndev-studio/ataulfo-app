import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/live_typing_progress.dart';
import 'package:ataulfo/core/design/widgets/typing_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppDesignTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('con etiqueta: typing + el texto de progreso, con keys por '
      'superficie', (tester) async {
    await tester.pumpWidget(
      _host(const LiveTypingProgress(label: 'Usando read_doc…', keyId: 'pa')),
    );
    // TypingBubble anima en loop: avanzar frames sin pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TypingBubble), findsOneWidget);
    expect(find.byKey(const Key('pa.typing')), findsOneWidget);
    expect(find.byKey(const Key('pa.live_progress')), findsOneWidget);
    expect(find.text('Usando read_doc…'), findsOneWidget);
  });

  testWidgets('sin etiqueta (SSE no conectó aún): solo el typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LiveTypingProgress(label: '', keyId: 'trainer')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('trainer.typing')), findsOneWidget);
    expect(find.byKey(const Key('trainer.live_progress')), findsNothing);
  });
}
