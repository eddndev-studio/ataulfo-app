import 'package:ataulfo/features/members/data/dto/member_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemberResp', () {
    test('parsea las claves del contrato GET /workspace/members', () {
      final json = <String, dynamic>{
        'id': 'm1',
        'user_id': 'u1',
        'email': 'a@x.com',
        'email_verified': true,
        'role': 'OWNER',
      };

      final resp = MemberResp.fromJson(json);

      expect(resp.id, 'm1');
      expect(resp.userId, 'u1');
      expect(resp.email, 'a@x.com');
      expect(resp.emailVerified, isTrue);
      expect(resp.role, 'OWNER');
    });

    test('lanza FormatException si falta id', () {
      final incomplete = <String, dynamic>{
        'user_id': 'u1',
        'email': 'a@x.com',
        'email_verified': true,
        'role': 'ADMIN',
      };

      expect(() => MemberResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si falta email', () {
      final incomplete = <String, dynamic>{
        'id': 'm1',
        'user_id': 'u1',
        'email_verified': true,
        'role': 'ADMIN',
      };

      expect(() => MemberResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si falta email_verified', () {
      final incomplete = <String, dynamic>{
        'id': 'm1',
        'user_id': 'u1',
        'email': 'a@x.com',
        'role': 'ADMIN',
      };

      expect(() => MemberResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si una clave tiene tipo equivocado', () {
      final wrongType = <String, dynamic>{
        'id': 'm1',
        'user_id': 'u1',
        'email': 'a@x.com',
        'email_verified': 'sí', // debería ser bool
        'role': 'ADMIN',
      };

      expect(() => MemberResp.fromJson(wrongType), throwsFormatException);
    });
  });
}
