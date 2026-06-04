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
        MembersSoleOwnerFailure(),
        MembersSelfRoleUpgradeFailure(),
        MembersNotFoundFailure(),
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
      const g = MembersSoleOwnerFailure();
      const h = MembersSelfRoleUpgradeFailure();
      const i = MembersNotFoundFailure();

      expect(a, isA<MembersNetworkFailure>());
      expect(b, isA<MembersTimeoutFailure>());
      expect(c, isA<MembersForbiddenFailure>());
      expect(d, isA<MembersNoActiveOrgFailure>());
      expect(e, isA<MembersServerFailure>());
      expect(f, isA<UnknownMembersFailure>());
      expect(g, isA<MembersSoleOwnerFailure>());
      expect(h, isA<MembersSelfRoleUpgradeFailure>());
      expect(i, isA<MembersNotFoundFailure>());

      expect(a, isNot(isA<MembersTimeoutFailure>()));
      expect(c, isNot(isA<MembersNoActiveOrgFailure>()));
      expect(e, isNot(isA<UnknownMembersFailure>()));
      // 403 y 409 colapsan a variantes distintas según el endpoint: el listado
      // mapea 409→NoActiveOrg, las mutaciones 409→SoleOwner; son tipos distintos.
      expect(g, isNot(isA<MembersNoActiveOrgFailure>()));
      expect(h, isNot(isA<MembersForbiddenFailure>()));
    });
  });
}
