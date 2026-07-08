import 'package:ataulfo/features/product_catalog/data/dto/product_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json() => <String, dynamic>{
  'id': 'p1',
  'kind': 'PRODUCT',
  'name': 'Mango Ataulfo',
  'description': 'Caja de 5 kg',
  'category': 'Fruta',
  'priceCents': 125000,
  'priceDisplay': r'$1,250.00 MXN',
  'mediaRef': 'tenant/org/media/m1.png',
  'active': true,
  'createdAt': '2026-07-01T00:00:00Z',
  'updatedAt': '2026-07-02T00:00:00Z',
};

void main() {
  test('json completo ⇒ DTO con los valores del wire', () {
    final dto = ProductDto.fromJson(_json());
    expect(dto.id, 'p1');
    expect(dto.kind, 'PRODUCT');
    expect(dto.name, 'Mango Ataulfo');
    expect(dto.description, 'Caja de 5 kg');
    expect(dto.category, 'Fruta');
    expect(dto.priceCents, 125000);
    expect(dto.priceDisplay, r'$1,250.00 MXN');
    expect(dto.mediaRef, 'tenant/org/media/m1.png');
    expect(dto.active, isTrue);
    expect(dto.createdAt, '2026-07-01T00:00:00Z');
    expect(dto.updatedAt, '2026-07-02T00:00:00Z');
  });

  test('strings vacíos del wire se conservan (precio a consultar, sin '
      'imagen)', () {
    final json = _json()
      ..['priceCents'] = 0
      ..['priceDisplay'] = ''
      ..['mediaRef'] = '';
    final dto = ProductDto.fromJson(json);
    expect(dto.priceCents, 0);
    expect(dto.priceDisplay, '');
    expect(dto.mediaRef, '');
  });

  test('clave ausente ⇒ FormatException (wire roto, no caso a tolerar)', () {
    for (final key in _json().keys) {
      final json = _json()..remove(key);
      expect(
        () => ProductDto.fromJson(json),
        throwsFormatException,
        reason: 'sin $key',
      );
    }
  });

  test('tipo inválido ⇒ FormatException', () {
    expect(
      () => ProductDto.fromJson(_json()..['priceCents'] = '125000'),
      throwsFormatException,
    );
    expect(
      () => ProductDto.fromJson(_json()..['active'] = 'yes'),
      throwsFormatException,
    );
  });
}
