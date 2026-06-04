import 'package:ataulfo/features/members/data/dto/member_dto.dart';
import 'package:ataulfo/features/members/data/mappers/members_mapper.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MembersMapper.respToEntity', () {
    test('MemberResp → Member preserva todos los campos', () {
      const resp = MemberResp(
        id: 'm1',
        userId: 'u1',
        email: 'a@x.com',
        emailVerified: true,
        role: 'OWNER',
      );

      final got = MembersMapper.respToEntity(resp);

      expect(
        got,
        const Member(
          id: 'm1',
          userId: 'u1',
          email: 'a@x.com',
          emailVerified: true,
          role: 'OWNER',
        ),
      );
    });
  });
}
