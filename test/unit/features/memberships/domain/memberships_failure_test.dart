import 'package:ataulfo/features/memberships/domain/failures/memberships_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MembershipsFailure', () {
    test('todas las variantes derivan de MembershipsFailure (sellada)', () {
      const failures = <MembershipsFailure>[
        MembershipsNetworkFailure(),
        MembershipsTimeoutFailure(),
        MembershipsForbiddenFailure(),
        MembershipsServerFailure(),
        UnknownMembershipsFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<MembershipsFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es de su propio tipo (no se cruzan)', () {
      const a = MembershipsNetworkFailure();
      const b = MembershipsTimeoutFailure();
      const c = MembershipsForbiddenFailure();
      const d = MembershipsServerFailure();
      const e = UnknownMembershipsFailure();

      expect(a, isA<MembershipsNetworkFailure>());
      expect(b, isA<MembershipsTimeoutFailure>());
      expect(c, isA<MembershipsForbiddenFailure>());
      expect(d, isA<MembershipsServerFailure>());
      expect(e, isA<UnknownMembershipsFailure>());

      expect(a, isNot(isA<MembershipsTimeoutFailure>()));
      expect(b, isNot(isA<MembershipsForbiddenFailure>()));
      expect(c, isNot(isA<MembershipsServerFailure>()));
    });
  });
}
