import 'package:ataulfo/features/product_catalog/presentation/peso_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePesosToCents', () {
    test('vacío o cero ⇒ 0 (a consultar)', () {
      expect(parsePesosToCents(''), 0);
      expect(parsePesosToCents('  '), 0);
      expect(parsePesosToCents('0'), 0);
      expect(parsePesosToCents('0.00'), 0);
    });

    test('enteros y decimales ⇒ centavos', () {
      expect(parsePesosToCents('1250'), 125000);
      expect(parsePesosToCents('1250.00'), 125000);
      expect(parsePesosToCents('1250.5'), 125050);
      expect(parsePesosToCents('0.50'), 50);
    });

    test('tolera separador de miles, símbolo y espacios', () {
      expect(parsePesosToCents('1,250.00'), 125000);
      expect(parsePesosToCents(r'$ 12,345.67'), 1234567);
    });

    test('inválidos ⇒ null (nunca adivina)', () {
      expect(parsePesosToCents('abc'), isNull);
      expect(parsePesosToCents('-5'), isNull);
      expect(parsePesosToCents('1.2.3'), isNull);
      expect(parsePesosToCents('1250.505'), isNull);
    });
  });

  group('formatCentsToPesos', () {
    test('0 ⇒ vacío (el campo queda libre para «a consultar»)', () {
      expect(formatCentsToPesos(0), '');
    });

    test('centavos ⇒ pesos con miles y dos decimales', () {
      expect(formatCentsToPesos(125000), '1,250.00');
      expect(formatCentsToPesos(50), '0.50');
      expect(formatCentsToPesos(1234567), '12,345.67');
    });
  });
}
