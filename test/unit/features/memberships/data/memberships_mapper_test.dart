import 'package:agentic/features/memberships/data/dto/membership_dto.dart';
import 'package:agentic/features/memberships/data/mappers/memberships_mapper.dart';
import 'package:agentic/features/memberships/domain/entities/membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MembershipsMapper.respToEntity', () {
    test('MembershipResp → Membership preserva los 3 campos', () {
      const resp = MembershipResp(
        orgId: 'o1',
        orgName: 'Acme Inc.',
        role: 'OWNER',
      );

      final got = MembershipsMapper.respToEntity(resp);

      expect(
        got,
        const Membership(orgId: 'o1', orgName: 'Acme Inc.', role: 'OWNER'),
      );
    });
  });
}
