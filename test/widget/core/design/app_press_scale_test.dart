import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool motion = true}) => AppMotion(
    enabled: motion,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  AnimatedScale scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale));

  testWidgets('en reposo no escala (1.0)', (tester) async {
    await tester.pumpWidget(
      host(
        const AppPressScale(
          pressed: false,
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );
    expect(scaleOf(tester).scale, 1.0);
  });

  testWidgets('presionado encoge al scale del kit (0.97 default)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppPressScale(
          pressed: true,
          child: SizedBox.square(dimension: 40),
        ),
      ),
    );
    expect(scaleOf(tester).scale, 0.97);
    expect(scaleOf(tester).duration, AppTokens.durationFast);
  });

  testWidgets('acepta un scale propio (superficies grandes encogen menos)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppPressScale(
          pressed: true,
          scale: 0.98,
          child: SizedBox.square(dimension: 200),
        ),
      ),
    );
    expect(scaleOf(tester).scale, 0.98);
  });

  testWidgets('con AppMotion apagado no se mueve: scale 1.0 y duración cero '
      'aunque esté presionado', (tester) async {
    await tester.pumpWidget(
      host(
        const AppPressScale(
          pressed: true,
          child: SizedBox.square(dimension: 40),
        ),
        motion: false,
      ),
    );
    expect(scaleOf(tester).scale, 1.0);
    expect(scaleOf(tester).duration, Duration.zero);
  });
}
