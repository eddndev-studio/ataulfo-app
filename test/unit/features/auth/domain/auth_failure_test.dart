import 'package:ataulfo/features/auth/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthFailure — variantes nuevas del arco de onboarding', () {
    test('EmailTakenFailure es un AuthFailure', () {
      const failure = EmailTakenFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('WeakPasswordFailure es un AuthFailure', () {
      const failure = WeakPasswordFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('InvalidTokenFailure es un AuthFailure', () {
      const failure = InvalidTokenFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('ExpiredTokenFailure es un AuthFailure', () {
      const failure = ExpiredTokenFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('EmailMismatchFailure es un AuthFailure', () {
      const failure = EmailMismatchFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('AlreadyMemberFailure es un AuthFailure', () {
      const failure = AlreadyMemberFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('NotMemberFailure es un AuthFailure', () {
      const failure = NotMemberFailure();
      expect(failure, isA<AuthFailure>());
    });

    test('las variantes nuevas son distinguibles entre sí por tipo', () {
      const failures = <AuthFailure>[
        EmailTakenFailure(),
        WeakPasswordFailure(),
        InvalidTokenFailure(),
        ExpiredTokenFailure(),
        EmailMismatchFailure(),
        AlreadyMemberFailure(),
        NotMemberFailure(),
      ];
      // Cada variante mapea a un único runtimeType — el switch sellado del
      // consumidor puede ramificar por caso sin colisiones.
      final types = failures.map((f) => f.runtimeType).toSet();
      expect(types.length, failures.length);
    });
  });
}
