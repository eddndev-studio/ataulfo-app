import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/widgets/app_icon_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {bool motion = true}) => AppMotion(
    enabled: motion,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  double scaleOf(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AppIconPop),
        matching: find.byType(Transform),
      ),
    );
    // Transform.scale codifica la escala en la diagonal de la matriz; se lee
    // el eje X (el Z queda en 1.0, así que getMaxScaleOnAxis mentiría).
    return transform.transform.entry(0, 0);
  }

  testWidgets('pinta el ícono pedido', (tester) async {
    await tester.pumpWidget(host(const AppIconPop(icon: Icons.smart_toy)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.smart_toy), findsOneWidget);
  });

  testWidgets('al montarse hace pop: arranca encogido y asienta en 1.0', (
    tester,
  ) async {
    await tester.pumpWidget(host(const AppIconPop(icon: Icons.smart_toy)));
    // Primer frame: aún cerca del inicio (encogido).
    expect(scaleOf(tester), lessThan(1.0));

    await tester.pumpAndSettle();
    // easeSpring sobrepasa 1.0 a mitad de curva pero asienta exacto.
    expect(scaleOf(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('con AppMotion apagado no hay pop: primer frame ya en 1.0', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppIconPop(icon: Icons.smart_toy), motion: false),
    );
    expect(scaleOf(tester), moreOrLessEquals(1.0, epsilon: 0.001));
    // Nada queda animando.
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
