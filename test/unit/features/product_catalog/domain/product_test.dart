import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _make({
  String id = 'p1',
  ProductKind kind = ProductKind.product,
  String name = 'Mango Ataulfo',
  String description = 'Caja de 5 kg',
  String category = 'Fruta',
  int priceCents = 125000,
  String priceDisplay = r'$1,250.00 MXN',
  String mediaRef = 'tenant/org/media/m1.png',
  bool active = true,
}) => Product(
  id: id,
  kind: kind,
  name: name,
  description: description,
  category: category,
  priceCents: priceCents,
  priceDisplay: priceDisplay,
  mediaRef: mediaRef,
  active: active,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 2),
);

void main() {
  test('igualdad por valor: mismos campos ⇒ iguales', () {
    expect(_make(), _make());
    expect(_make().hashCode, _make().hashCode);
  });

  test('igualdad por valor: un campo distinto ⇒ difieren', () {
    expect(_make(), isNot(_make(id: 'p2')));
    expect(_make(), isNot(_make(kind: ProductKind.service)));
    expect(_make(), isNot(_make(priceCents: 0)));
    expect(_make(), isNot(_make(active: false)));
  });

  test('hasPrice: centavos > 0 ⇒ tiene precio; 0 ⇒ a consultar', () {
    expect(_make(priceCents: 125000).hasPrice, isTrue);
    expect(_make(priceCents: 0).hasPrice, isFalse);
  });

  test('hasImage: ref no vacío ⇒ tiene imagen', () {
    expect(_make().hasImage, isTrue);
    expect(_make(mediaRef: '').hasImage, isFalse);
  });
}
