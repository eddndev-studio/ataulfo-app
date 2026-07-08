import 'package:ataulfo/features/product_catalog/data/dto/product_dto.dart';
import 'package:ataulfo/features/product_catalog/data/mappers/product_mapper.dart';
import 'package:ataulfo/features/product_catalog/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';

ProductDto _dto({String kind = 'PRODUCT'}) => ProductDto(
  id: 'p1',
  kind: kind,
  name: 'Mango Ataulfo',
  description: 'Caja de 5 kg',
  category: 'Fruta',
  priceCents: 125000,
  priceDisplay: r'$1,250.00 MXN',
  mediaRef: 'tenant/org/media/m1.png',
  active: true,
  createdAt: '2026-07-01T12:00:00Z',
  updatedAt: '2026-07-02T00:00:00Z',
);

void main() {
  test('dtoToEntity mapea campos y parsea instantes UTC', () {
    final p = ProductMapper.dtoToEntity(_dto());
    expect(p.id, 'p1');
    expect(p.kind, ProductKind.product);
    expect(p.name, 'Mango Ataulfo');
    expect(p.priceCents, 125000);
    expect(p.createdAt, DateTime.utc(2026, 7, 1, 12));
    expect(p.createdAt.isUtc, isTrue);
    expect(p.updatedAt, DateTime.utc(2026, 7, 2));
  });

  test('kind del wire: SERVICE ⇒ service; desconocido ⇒ FormatException', () {
    expect(
      ProductMapper.dtoToEntity(_dto(kind: 'SERVICE')).kind,
      ProductKind.service,
    );
    expect(
      () => ProductMapper.dtoToEntity(_dto(kind: 'COMBO')),
      throwsFormatException,
    );
  });

  test('kindToWire: ida y vuelta con el set cerrado del wire', () {
    expect(ProductMapper.kindToWire(ProductKind.product), 'PRODUCT');
    expect(ProductMapper.kindToWire(ProductKind.service), 'SERVICE');
  });
}
