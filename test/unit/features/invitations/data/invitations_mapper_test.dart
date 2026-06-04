import 'package:ataulfo/features/invitations/data/dto/invitation_dto.dart';
import 'package:ataulfo/features/invitations/data/mappers/invitations_mapper.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvitationsMapper.respToEntity', () {
    test('InvitationResp → Invitation preserva los campos', () {
      final resp = InvitationResp(
        id: 'i1',
        email: 'a@x.com',
        role: 'ADMIN',
        status: 'PENDING',
        expiresAt: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 5, 25),
      );

      final got = InvitationsMapper.respToEntity(resp);

      expect(
        got,
        Invitation(
          id: 'i1',
          email: 'a@x.com',
          role: 'ADMIN',
          status: 'PENDING',
          expiresAt: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 5, 25),
        ),
      );
    });
  });
}
