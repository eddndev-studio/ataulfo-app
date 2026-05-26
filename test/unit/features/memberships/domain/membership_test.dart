import 'package:agentic/features/memberships/domain/entities/membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Membership', () {
    test('expone los 3 campos decorados de GET /auth/memberships', () {
      const m = Membership(orgId: 'o1', orgName: 'Acme Inc.', role: 'OWNER');

      expect(m.orgId, 'o1');
      expect(m.orgName, 'Acme Inc.');
      expect(m.role, 'OWNER');
    });

    test('dos Membership con misma data son iguales (value-type)', () {
      const a = Membership(orgId: 'o1', orgName: 'Acme', role: 'ADMIN');
      const b = Membership(orgId: 'o1', orgName: 'Acme', role: 'ADMIN');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia cualquiera de los 3 campos', () {
      const base = Membership(orgId: 'o1', orgName: 'Acme', role: 'ADMIN');
      const otherOrgId = Membership(
        orgId: 'o2',
        orgName: 'Acme',
        role: 'ADMIN',
      );
      const otherName = Membership(orgId: 'o1', orgName: 'Otra', role: 'ADMIN');
      const otherRole = Membership(
        orgId: 'o1',
        orgName: 'Acme',
        role: 'WORKER',
      );

      expect(base, isNot(otherOrgId));
      expect(base, isNot(otherName));
      expect(base, isNot(otherRole));
    });
  });
}
