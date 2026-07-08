import 'package:ataulfo/features/product_catalog/domain/failures/product_catalog_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ValidationFailure: igualdad por mensaje', () {
    expect(
      const ProductCatalogValidationFailure('x'),
      const ProductCatalogValidationFailure('x'),
    );
    expect(
      const ProductCatalogValidationFailure('x'),
      isNot(const ProductCatalogValidationFailure('y')),
    );
    expect(
      const ProductCatalogValidationFailure(),
      const ProductCatalogValidationFailure(),
    );
  });

  test('los failures son Exception atrapables', () {
    expect(const ProductCatalogNetworkFailure(), isA<Exception>());
    expect(const ProductCatalogTimeoutFailure(), isA<Exception>());
    expect(const ProductCatalogForbiddenFailure(), isA<Exception>());
    expect(const ProductCatalogNotFoundFailure(), isA<Exception>());
    expect(const ProductCatalogServerFailure(), isA<Exception>());
    expect(const UnknownProductCatalogFailure(), isA<Exception>());
  });
}
