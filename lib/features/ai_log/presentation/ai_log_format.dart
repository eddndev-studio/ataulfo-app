/// Formateadores del header de tokens/costo de la corrida del ai-log. Puros y
/// sin estado, sin `intl` (no es dependencia del repo): el header los comparte
/// con los tests unitarios que fijan sus ejemplos exactos.
library;

/// Conteo de tokens abreviado para caber en un pill. Por debajo de mil se
/// muestra el número tal cual ("730"); miles con un decimal y sufijo "k"
/// ("12.3k"), y millones con "M" ("1.2M"). El decimal redondo se recorta para
/// no arrastrar un ".0" muerto ("35k", no "35.0k").
String formatTokensCompact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final s = _oneDecimal(n / 1000);
    // 999950..999999 redondean a "1000": promover a la unidad mayor evita el
    // híbrido "1000k".
    if (s == '1000') return '1M';
    return '${s}k';
  }
  return '${_oneDecimal(n / 1000000)}M';
}

/// Un decimal, recortando el ".0" cuando el valor es redondo.
String _oneDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Costo en dólares a partir de micro-USD (1e-6 USD), el entero que emite el
/// wire. A partir de un dólar bastan dos decimales ("$1.25"); por debajo se
/// muestran hasta cuatro decimales recortando ceros finales pero nunca por
/// debajo de dos ("$0.04", "$0.0362", "$0.0028"). Un costo real tan chico que
/// redondea a cero a cuatro decimales se señala con el piso "<$0.0001" — el
/// pill solo se pinta con costo > 0 y "$0.0000" afirmaría cero para un turno
/// con costo registrado. El costo ausente o cero da "$0.00" — red de
/// seguridad; el header no pinta ese pill.
String formatMicroUsd(int micros) {
  if (micros <= 0) return r'$0.00';
  final dollars = micros / 1000000;
  if (dollars >= 1) return '\$${dollars.toStringAsFixed(2)}';
  final s = _trimmed(dollars, max: 4, min: 2);
  if (s == '0.00') return r'<$0.0001';
  return '\$$s';
}

/// Fija [max] decimales, recorta los ceros finales y vuelve a rellenar hasta un
/// piso de [min] decimales (para no dejar "$0.4" donde se espera "$0.40").
String _trimmed(double v, {required int max, required int min}) {
  var s = v.toStringAsFixed(max);
  while (s.contains('.') && s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  final dot = s.indexOf('.');
  final decimals = dot < 0 ? 0 : s.length - dot - 1;
  if (decimals >= min) return s;
  final base = dot < 0 ? '$s.' : s;
  return base + '0' * (min - decimals);
}
