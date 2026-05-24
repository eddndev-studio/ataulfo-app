import 'package:agentic/features/auth/data/dto/login_dto.dart';
import 'package:agentic/features/auth/data/mappers/auth_mapper.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Identity', () {
    test('expone los 3 campos derivados del access token (S02 /auth/me)', () {
      const id = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

      expect(id.userId, 'u1');
      expect(id.orgId, 'o1');
      expect(id.role, 'OWNER');
    });

    test('dos Identity con misma data son iguales (value-type)', () {
      const a = Identity(userId: 'u1', orgId: 'o1', role: 'ADMIN');
      const b = Identity(userId: 'u1', orgId: 'o1', role: 'ADMIN');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia cualquiera de los 3 campos', () {
      const base = Identity(userId: 'u1', orgId: 'o1', role: 'ADMIN');
      const otherUser = Identity(userId: 'u2', orgId: 'o1', role: 'ADMIN');
      const otherOrg = Identity(userId: 'u1', orgId: 'o2', role: 'ADMIN');
      const otherRole = Identity(userId: 'u1', orgId: 'o1', role: 'WORKER');

      expect(base, isNot(otherUser));
      expect(base, isNot(otherOrg));
      expect(base, isNot(otherRole));
    });
  });

  group('AuthMapper.meRespToEntity', () {
    test('MeResp → Identity preserva los 3 campos', () {
      const resp = MeResp(userId: 'u1', orgId: 'o1', role: 'OWNER');

      final identity = AuthMapper.meRespToEntity(resp);

      expect(
        identity,
        const Identity(userId: 'u1', orgId: 'o1', role: 'OWNER'),
      );
    });
  });
}
