import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Member', () {
    test('expone los campos del contrato GET /workspace/members', () {
      const m = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'OWNER',
      );

      expect(m.id, 'm1');
      expect(m.userId, 'u1');
      expect(m.email, 'a@x.com');
      expect(m.emailVerified, isTrue);
      expect(m.role, 'OWNER');
    });

    test('dos Member con misma data son iguales (value-type)', () {
      const a = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'ADMIN',
      );
      const b = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'ADMIN',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia cualquier campo', () {
      const base = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'ADMIN',
      );
      const otherId = Member(
        id: 'm2',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'ADMIN',
      );
      const otherEmail = Member(
        id: 'm1',
        userId: 'u1',
        email: 'b@x.com',
        emailVerified: true,
        role: 'ADMIN',
      );
      const otherVerified = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: false,
        role: 'ADMIN',
      );
      const otherRole = Member(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'WORKER',
      );

      expect(base, isNot(otherId));
      expect(base, isNot(otherEmail));
      expect(base, isNot(otherVerified));
      expect(base, isNot(otherRole));
    });
  });
}
