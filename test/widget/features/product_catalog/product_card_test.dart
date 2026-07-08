import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_media_thumb.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:ataulfo/features/product_catalog/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p({
  ProductKind kind = ProductKind.product,
  String priceDisplay = r'$1,250.00 MXN',
  String mediaRef = '',
  bool active = true,
}) => Product(
  id: 'p1',
  kind: kind,
  name: 'Mango Ataulfo',
  description: 'Caja de 5 kg',
  category: 'Fruta',
  priceCents: priceDisplay.isEmpty ? 0 : 125000,
  priceDisplay: priceDisplay,
  mediaRef: mediaRef,
  active: active,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Product product, {
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppDesignTheme.dark(),
      home: Scaffold(
        body: ProductCard(
          product: product,
          onTap: onTap ?? () {},
          thumbLoader: (_) async => null,
        ),
      ),
    ),
  );

  testWidgets('pinta nombre, categoría, precio y chip PRODUCTO', (
    tester,
  ) async {
    await pump(tester, _p());
    expect(find.text('Mango Ataulfo'), findsOneWidget);
    expect(find.textContaining('Fruta'), findsOneWidget);
    expect(find.text(r'$1,250.00 MXN'), findsOneWidget);
    expect(find.text('PRODUCTO'), findsOneWidget);
  });

  testWidgets('sin priceDisplay ⇒ «Precio a consultar»', (tester) async {
    await pump(tester, _p(priceDisplay: ''));
    expect(find.text('Precio a consultar'), findsOneWidget);
  });

  testWidgets('servicio ⇒ chip SERVICIO', (tester) async {
    await pump(tester, _p(kind: ProductKind.service));
    expect(find.text('SERVICIO'), findsOneWidget);
  });

  testWidgets('inactivo ⇒ contenido atenuado', (tester) async {
    await pump(tester, _p(active: false));
    final opacity = tester.widget<Opacity>(
      find.byKey(const Key('product_catalog.card.dim')),
    );
    expect(opacity.opacity, lessThan(1.0));
    expect(find.textContaining('inactivo'), findsOneWidget);
  });

  testWidgets('activo ⇒ sin atenuar', (tester) async {
    await pump(tester, _p());
    final opacity = tester.widget<Opacity>(
      find.byKey(const Key('product_catalog.card.dim')),
    );
    expect(opacity.opacity, 1.0);
  });

  testWidgets('tap dispara onTap', (tester) async {
    var tapped = false;
    await pump(tester, _p(), onTap: () => tapped = true);
    await tester.tap(find.byKey(const Key('product_catalog.card.p1')));
    expect(tapped, isTrue);
  });

  testWidgets('con mediaRef ⇒ miniatura; sin él ⇒ glifo de producto', (
    tester,
  ) async {
    await pump(tester, _p(mediaRef: 'tenant/org/media/m1.png'));
    expect(find.byType(AppMediaThumb), findsOneWidget);

    await pump(tester, _p());
    expect(find.byType(AppMediaThumb), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });
}
