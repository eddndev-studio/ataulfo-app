import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_background.dart';

void main() {
  group('AppBackground', () {
    testWidgets('pinta SOLO el lienzo oscuro sólido — sin capas de glow', (
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

      // Cero capas de gradiente: el fondo es oscuro sólido (el glow
      // "amanecer" se retiró; los gradientes viven solo como FILL de
      // componentes — headers, botones — nunca como fondo).
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
      expect(gradients, isEmpty);
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
