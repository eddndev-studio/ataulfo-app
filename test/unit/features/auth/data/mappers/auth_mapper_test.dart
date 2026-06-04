import 'package:ataulfo/features/auth/data/dto/login_dto.dart';
import 'package:ataulfo/features/auth/data/mappers/auth_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthMapper.meRespToEntity', () {
    test('traduce los claims básicos a Identity', () {
      const resp = MeResp(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
      );

      final identity = AuthMapper.meRespToEntity(resp);

      expect(identity.userId, 'u1');
      expect(identity.orgId, 'o1');
      expect(identity.role, 'OWNER');
      expect(identity.email, 'op@example.com');
    });

    test('carga emailVerified=true del wire', () {
      const resp = MeResp(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
        emailVerified: true,
      );

      expect(AuthMapper.meRespToEntity(resp).emailVerified, isTrue);
    });

    test('emailVerified por defecto es false (sesión sin la verificación)', () {
      const resp = MeResp(
        userId: 'u1',
        orgId: 'o1',
        role: 'OWNER',
        email: 'op@example.com',
      );

      expect(AuthMapper.meRespToEntity(resp).emailVerified, isFalse);
    });
  });
}
