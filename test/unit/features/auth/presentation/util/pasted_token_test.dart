import 'package:ataulfo/features/auth/presentation/util/pasted_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractPastedToken', () {
    test('token crudo: devuelve el texto recortado tal cual', () {
      expect(extractPastedToken('abc123'), 'abc123');
    });

    test('recorta espacios alrededor del token crudo', () {
      expect(extractPastedToken('  abc123  '), 'abc123');
    });

    test('URL completa con ?token=: extrae el valor del query', () {
      expect(
        extractPastedToken('https://ataulfo.app/reset?token=abc123'),
        'abc123',
      );
    });

    test('URL con token percent-encoded: lo devuelve decodificado una vez', () {
      // `a+b/c=` viaja como `a%2Bb%2Fc%3D`; el parser de Uri ya decodifica
      // una vez, así que el token sale con los caracteres literales.
      expect(
        extractPastedToken('https://ataulfo.app/reset?token=a%2Bb%2Fc%3D'),
        'a+b/c=',
      );
    });

    test('URL con otros params además de token: aísla token', () {
      expect(
        extractPastedToken('https://ataulfo.app/reset?foo=1&token=xyz&bar=2'),
        'xyz',
      );
    });

    test('cadena en blanco: devuelve vacío', () {
      expect(extractPastedToken(''), '');
      expect(extractPastedToken('   '), '');
    });
  });
}
