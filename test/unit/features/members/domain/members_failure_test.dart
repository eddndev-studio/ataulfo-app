import 'package:ataulfo/features/members/domain/failures/members_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MembersFailure', () {
    test('todas las variantes derivan de MembersFailure (sellada)', () {
      const failures = <MembersFailure>[
        MembersNetworkFailure(),
        MembersTimeoutFailure(),
        MembersForbiddenFailure(),
        MembersNoActiveOrgFailure(),
        MembersServerFailure(),
        UnknownMembersFailure(),
      ];

      for (final f in failures) {
        expect(f, isA<MembersFailure>());
        expect(f, isA<Exception>());
      }
    });

    test('cada variante es de su propio tipo (no se cruzan)', () {
      const a = MembersNetworkFailure();
      const b = MembersTimeoutFailure();
      const c = MembersForbiddenFailure();
      const d = MembersNoActiveOrgFailure();
      const e = MembersServerFailure();
      const f = UnknownMembersFailure();

      expect(a, isA<MembersNetworkFailure>());
      expect(b, isA<MembersTimeoutFailure>());
      expect(c, isA<MembersForbiddenFailure>());
      expect(d, isA<MembersNoActiveOrgFailure>());
      expect(e, isA<MembersServerFailure>());
      expect(f, isA<UnknownMembersFailure>());

      expect(a, isNot(isA<MembersTimeoutFailure>()));
      expect(c, isNot(isA<MembersNoActiveOrgFailure>()));
      expect(e, isNot(isA<UnknownMembersFailure>()));
    });
  });
}
