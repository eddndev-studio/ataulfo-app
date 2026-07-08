// Conversión entre el precio EDITABLE en pesos («1,250.00») y los centavos
// del wire. El formato LEGIBLE del catálogo no vive aquí: lo fabrica el
// backend en `priceDisplay` (fuente única); estos helpers solo alimentan el
// campo del formulario.

/// Centavos a partir del texto del campo de precio. Tolera símbolo `$`,
/// espacios y comas de miles. Vacío o cero ⇒ 0 («a consultar»). Devuelve
/// null si el texto no es un precio válido (letras, negativo, más de dos
/// decimales): el formulario muestra error en vez de adivinar.
int? parsePesosToCents(String input) {
  final cleaned = input.replaceAll(r'$', '').replaceAll(',', '').trim();
  if (cleaned.isEmpty) return 0;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final pesos = int.parse(match.group(1)!);
  final decimals = match.group(2) ?? '';
  final cents = int.parse(decimals.padRight(2, '0').padLeft(2, '0'));
  return pesos * 100 + cents;
}

/// Texto editable a partir de los centavos guardados: pesos con separador de
/// miles y dos decimales. 0 ⇒ '' (el campo queda vacío y el producto se
/// publica «a consultar»).
String formatCentsToPesos(int cents) {
  if (cents <= 0) return '';
  final pesos = cents ~/ 100;
  final rem = (cents % 100).toString().padLeft(2, '0');
  final digits = pesos.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '$grouped.$rem';
}
