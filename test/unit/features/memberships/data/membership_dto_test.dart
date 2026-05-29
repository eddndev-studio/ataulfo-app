import 'package:ataulfo/features/memberships/data/dto/membership_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MembershipResp', () {
    test('parsea las 3 claves del contrato GET /auth/memberships', () {
      final json = <String, dynamic>{
        'org_id': 'o1',
        'org_name': 'Acme Inc.',
        'role': 'OWNER',
      };

      final resp = MembershipResp.fromJson(json);

      expect(resp.orgId, 'o1');
      expect(resp.orgName, 'Acme Inc.');
      expect(resp.role, 'OWNER');
    });

    test('lanza FormatException si falta org_id', () {
      final incomplete = <String, dynamic>{'org_name': 'Acme', 'role': 'ADMIN'};

      expect(() => MembershipResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si falta org_name', () {
      final incomplete = <String, dynamic>{'org_id': 'o1', 'role': 'ADMIN'};

      expect(() => MembershipResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si falta role', () {
      final incomplete = <String, dynamic>{'org_id': 'o1', 'org_name': 'Acme'};

      expect(() => MembershipResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si una clave tiene tipo equivocado', () {
      final wrongType = <String, dynamic>{
        'org_id': 'o1',
        'org_name': 42, // debería ser String
        'role': 'ADMIN',
      };

      expect(() => MembershipResp.fromJson(wrongType), throwsFormatException);
    });
  });
}
