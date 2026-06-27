import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_header_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    String greeting = 'Bienvenido, Op',
    String title = 'Agentes',
    String initial = 'O',
    IconData watermark = Icons.smart_toy,
    VoidCallback? onAvatarTap,
  }) => MaterialApp(
    home: Scaffold(
      body: AppHeaderCard(
        greeting: greeting,
        title: title,
        avatarInitial: initial,
        onAvatarTap: onAvatarTap ?? () {},
        watermark: watermark,
      ),
    ),
  );

  testWidgets('muestra saludo, título e inicial del avatar', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Bienvenido, Op'), findsOneWidget);
    expect(find.text('Agentes'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('tap en el avatar dispara onAvatarTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onAvatarTap: () => taps++));

    await tester.tap(find.byKey(const Key('header.avatar')));
    expect(taps, 1);
  });

  testWidgets('el avatar es un botón accesible etiquetado "Perfil"', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(
      tester.getSemantics(find.byKey(const Key('header.avatar'))),
      isSemantics(label: 'Perfil', isButton: true),
    );
  });

  testWidgets('renderiza el glifo de marca de agua de la sección', (
    tester,
  ) async {
    await tester.pumpWidget(host(watermark: Icons.description));

    expect(find.byIcon(Icons.description), findsOneWidget);
  });

  testWidgets('va soldado al borde superior: solo esquinas inferiores '
      'redondeadas', (tester) async {
    await tester.pumpWidget(host());

    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(AppHeaderCard),
        matching: find.byType(ClipRRect),
      ),
    );
    final radius = clip.borderRadius as BorderRadius;
    expect(radius.topLeft, Radius.zero);
    expect(radius.topRight, Radius.zero);
    expect(radius.bottomLeft, const Radius.circular(28));
    expect(radius.bottomRight, const Radius.circular(28));
  });

  testWidgets('fondo: gradiente de marca vertical ámbar→naranja', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((b) => b.gradient)
        .whereType<LinearGradient>();
    final brand = gradients.firstWhere(
      (g) =>
          g.colors.contains(AppTokens.primary) &&
          g.colors.contains(AppTokens.accent),
    );
    expect(brand.begin, Alignment.topCenter);
    expect(brand.end, Alignment.bottomCenter);
  });
}
