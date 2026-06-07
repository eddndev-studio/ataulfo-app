import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_background.dart';

void main() {
  group('AppBackground', () {
    testWidgets('pinta el lienzo base + las capas del glow amanecer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppBackground(child: SizedBox(width: 100, height: 100)),
        ),
      );

      // Lienzo base en bgBase.
      final base = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(AppBackground),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(base.color, AppTokens.bgBase);

      // Una capa (DecoratedBox con gradiente) por cada capa del token, en orden.
      final gradients = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AppBackground),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => (b.decoration as BoxDecoration).gradient)
          .whereType<Gradient>()
          .toList();
      expect(gradients, AppTokens.backgroundGlowLayers);
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
