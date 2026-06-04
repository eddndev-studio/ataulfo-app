import 'package:ataulfo/features/auth/data/dto/login_dto.dart';
import 'package:ataulfo/features/auth/data/mappers/auth_mapper.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Identity', () {
    test('expone los 4 campos derivados del access token (S02 /auth/me)', () {
      const id = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
      );

      expect(id.userId, 'u1');
      expect(id.orgId, 'o1');
      expect(id.role, 'OWNER');
      expect(id.email, 'op@example.com');
    });

    test('dos Identity con misma data son iguales (value-type)', () {
      const a = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'ADMIN',
        email: 'op@example.com',
      );
      const b = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'ADMIN',
        email: 'op@example.com',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia cualquiera de los 4 campos', () {
      const base = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'ADMIN',
        email: 'op@example.com',
      );
      const otherUser = Identity(
        userId: 'u2',
        orgId: 'o1',
        role: 'ADMIN',
        email: 'op@example.com',
      );
      const otherOrg = Identity(
        userId: 'u1',
        orgId: 'o2',
        role: 'ADMIN',
        email: 'op@example.com',
      );
      const otherRole = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'WORKER',
        email: 'op@example.com',
      );
      const otherEmail = Identity(
        userId: 'u1',
        orgId: 'o1',
        role: 'ADMIN',
        email: 'other@example.com',
      );

      expect(base, isNot(otherUser));
      expect(base, isNot(otherOrg));
      expect(base, isNot(otherRole));
      expect(base, isNot(otherEmail));
    });

    group('hasActiveOrg', () {
      test('true cuando orgId y role no están vacíos', () {
        const id = Identity(
          userId: 'u1',
          orgId: 'o1',
          role: 'OWNER',
          email: 'op@example.com',
        );

        expect(id.hasActiveOrg, isTrue);
      });

      test('false cuando orgId está vacío (usuario multi-membership)', () {
        const id = Identity(
          userId: 'u1',
          orgId: '',
          role: '',
          email: 'op@example.com',
        );

        expect(id.hasActiveOrg, isFalse);
      });

      test('false cuando role está vacío aunque orgId tenga valor', () {
        const id = Identity(
          userId: 'u1',
          orgId: 'o1',
          role: '',
          email: 'op@example.com',
        );

        expect(id.hasActiveOrg, isFalse);
      });
    });
  });

  group('AuthMapper.meRespToEntity', () {
    test('MeResp → Identity preserva los 4 campos', () {
      const resp = MeResp(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
      );

      final identity = AuthMapper.meRespToEntity(resp);

      expect(
        identity,
        const Identity(
          userId: 'u1',
          orgId: 'o1',
          role: 'OWNER',
          email: 'op@example.com',
        ),
      );
    });
  });
}
