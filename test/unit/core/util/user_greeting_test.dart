import 'package:ataulfo/core/util/user_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userGreeting', () {
    test('deriva nombre e inicial de la parte local del email', () {
      final r = userGreeting('op@example.com');
      expect(r.greeting, 'Bienvenido, Op');
      expect(r.initial, 'O');
    });

    test('capitaliza solo la primera letra; conserva el resto', () {
      final r = userGreeting('maria.lopez@x.io');
      expect(r.greeting, 'Bienvenido, Maria.lopez');
      expect(r.initial, 'M');
    });

    test('sin "@" usa el valor completo como nombre', () {
      final r = userGreeting('Smoke');
      expect(r.greeting, 'Bienvenido, Smoke');
      expect(r.initial, 'S');
    });

    test('email vacío cae al saludo neutro con inicial "?"', () {
      final r = userGreeting('');
      expect(r.greeting, 'Te damos la bienvenida');
      expect(r.initial, '?');
    });

    test('parte local en blanco (solo espacios) cae al saludo neutro', () {
      final r = userGreeting('   @example.com');
      expect(r.greeting, 'Te damos la bienvenida');
      expect(r.initial, '?');
    });
  });
}
