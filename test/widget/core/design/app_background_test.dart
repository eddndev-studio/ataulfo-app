import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_background.dart';

void main() {
  group('AppBackground', () {
    testWidgets('pinta el glow radial del kit sobre el lienzo', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppBackground(child: SizedBox(width: 100, height: 100)),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppBackground),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.gradient, AppTokens.backgroundGlow);
    });

    testWidgets('renderiza su child', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppBackground(child: Text('hola')),
        ),
      );
      expect(find.text('hola'), findsOneWidget);
    });
  });
}
