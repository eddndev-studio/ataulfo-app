import 'package:ataulfo/features/ai_log/presentation/ai_log_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTokensCompact', () {
    test('por debajo de mil: el número tal cual', () {
      expect(formatTokensCompact(730), '730');
    });

    test('miles con un decimal y sufijo k', () {
      expect(formatTokensCompact(12300), '12.3k');
    });

    test('miles redondos: recorta el ".0"', () {
      expect(formatTokensCompact(35000), '35k');
    });

    test('millones con un decimal y sufijo M', () {
      expect(formatTokensCompact(1200000), '1.2M');
    });

    test('miles que redondean a mil: promueve a "1M", no "1000k"', () {
      expect(formatTokensCompact(999950), '1M');
      expect(formatTokensCompact(999999), '1M');
    });

    test('borde justo antes de promover: sigue en "k"', () {
      expect(formatTokensCompact(999949), '999.9k');
    });
  });

  group('formatMicroUsd', () {
    test('a partir de un dólar: dos decimales', () {
      expect(formatMicroUsd(1250000), r'$1.25');
    });

    test('centavos: recorta ceros finales pero mantiene dos decimales', () {
      expect(formatMicroUsd(40000), r'$0.04');
    });

    test('fracción fina ≥ un centavo: hasta cuatro decimales', () {
      expect(formatMicroUsd(36200), r'$0.0362');
    });

    test('por debajo de un centavo: cuatro decimales', () {
      expect(formatMicroUsd(2800), r'$0.0028');
    });

    test('costo real que redondea a cero: piso visible, no "\$0.0000"', () {
      expect(formatMicroUsd(30), r'<$0.0001');
      expect(formatMicroUsd(49), r'<$0.0001');
    });

    test('el mínimo representable a cuatro decimales', () {
      expect(formatMicroUsd(50), r'$0.0001');
    });

    test('justo bajo el centavo: recorta ceros finales ("\$0.01")', () {
      expect(formatMicroUsd(9999), r'$0.01');
    });

    test('cero ⇒ "\$0.00" (la UI no lo pinta)', () {
      expect(formatMicroUsd(0), r'$0.00');
    });
  });
}
