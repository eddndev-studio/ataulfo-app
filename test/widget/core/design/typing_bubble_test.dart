import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/typing_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  testWidgets('pinta tres puntos dentro de una burbuja ajena', (tester) async {
    await tester.pumpWidget(host(const TypingBubble()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('typing_bubble.dot.0')), findsOneWidget);
    expect(find.byKey(const Key('typing_bubble.dot.1')), findsOneWidget);
    expect(find.byKey(const Key('typing_bubble.dot.2')), findsOneWidget);
  });

  testWidgets('los puntos pulsan (la opacidad cambia entre frames)', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TypingBubble()));

    double opacityAt(int i) => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byKey(Key('typing_bubble.dot.$i')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    await tester.pump(const Duration(milliseconds: 80));
    final before = opacityAt(0);
    await tester.pump(const Duration(milliseconds: 240));
    final after = opacityAt(0);
    expect(after, isNot(equals(before)));
  });
}
