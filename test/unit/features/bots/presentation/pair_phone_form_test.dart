import 'package:ataulfo/features/bots/presentation/pair_phone_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saneaTelefono', () {
    test('pela +, espacios, guiones y paréntesis', () {
      expect(saneaTelefono('+52 1 (55) 1234-5678'), '5215512345678');
    });

    test('un número ya limpio pasa intacto', () {
      expect(saneaTelefono('5215512345678'), '5215512345678');
    });

    test('cadena vacía queda vacía', () {
      expect(saneaTelefono(''), '');
    });
  });

  group('validaTelefono', () {
    test('MX con decoración es válido (se valida el saneado)', () {
      expect(validaTelefono('+52 1 (55) 1234-5678'), isNull);
    });

    test('MX limpio es válido', () {
      expect(validaTelefono('5215512345678'), isNull);
    });

    test('7 dígitos ya pasa', () {
      expect(validaTelefono('1234567'), isNull);
    });

    test('corto (< 7 dígitos) → copy de lada', () {
      expect(validaTelefono('123456'), 'Escribe el número completo con lada.');
    });

    test('vacío → copy de lada', () {
      expect(validaTelefono(''), 'Escribe el número completo con lada.');
    });

    test('inicia en 0 → copy de formato internacional', () {
      expect(
        validaTelefono('05512345678'),
        'Quita el 0 inicial: formato internacional.',
      );
    });

    test('corto E inicia en 0: el largo se revisa ANTES que el 0 inicial', () {
      expect(validaTelefono('0123'), 'Escribe el número completo con lada.');
    });
  });
}
