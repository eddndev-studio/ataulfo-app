import 'package:ataulfo/app.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Identity _id(String orgId) =>
    Identity(userId: 'u', orgId: orgId, role: 'OWNER', email: 'u@x');

void main() {
  group('isActiveOrgChange', () {
    test('dos autenticados con org distinta → true', () {
      expect(
        isActiveOrgChange(
          AuthAuthenticated(_id('org-A')),
          AuthAuthenticated(_id('org-B')),
        ),
        isTrue,
      );
    });

    test('misma org activa → false (no hay frontera que purgar)', () {
      expect(
        isActiveOrgChange(
          AuthAuthenticated(_id('org-A')),
          AuthAuthenticated(_id('org-A')),
        ),
        isFalse,
      );
    });

    test('logout (→ Unauthenticated) → false (lo gestiona onSignedOut)', () {
      expect(
        isActiveOrgChange(
          AuthAuthenticated(_id('org-A')),
          const AuthUnauthenticated(),
        ),
        isFalse,
      );
    });

    test('login (Initial → Authenticated) → false', () {
      expect(
        isActiveOrgChange(const AuthInitial(), AuthAuthenticated(_id('org-A'))),
        isFalse,
      );
    });

    test('desde "sin org activa" → false (no es org→otra-org)', () {
      expect(
        isActiveOrgChange(
          AuthAuthenticatedNoOrg(_id('')),
          AuthAuthenticated(_id('org-A')),
        ),
        isFalse,
      );
    });
  });
}
