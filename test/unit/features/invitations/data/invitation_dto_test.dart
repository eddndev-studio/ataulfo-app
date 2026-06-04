import 'package:ataulfo/features/invitations/data/dto/invitation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvitationResp', () {
    test('parsea las claves del contrato GET /workspace/invitations', () {
      final json = <String, dynamic>{
        'id': 'i1',
        'org_id': 'o1',
        'email': 'a@x.com',
        'role': 'WORKER',
        'status': 'PENDING',
        'expires_at': '2026-06-01T12:00:00Z',
        'created_at': '2026-05-25T09:30:00Z',
      };

      final resp = InvitationResp.fromJson(json);

      expect(resp.id, 'i1');
      expect(resp.email, 'a@x.com');
      expect(resp.role, 'WORKER');
      expect(resp.status, 'PENDING');
      expect(resp.expiresAt, DateTime.utc(2026, 6, 1, 12));
      expect(resp.createdAt, DateTime.utc(2026, 5, 25, 9, 30));
    });

    test('expires_at con sufijo Z se parsea como instante UTC', () {
      final json = <String, dynamic>{
        'id': 'i1',
        'email': 'a@x.com',
        'role': 'WORKER',
        'status': 'PENDING',
        'expires_at': '2026-06-01T00:00:00Z',
        'created_at': '2026-05-25T00:00:00Z',
      };

      final resp = InvitationResp.fromJson(json);

      expect(resp.expiresAt.isUtc, isTrue);
      // Un now posterior al instante UTC debe quedar después, comparando bien.
      expect(DateTime.utc(2026, 6, 2).isAfter(resp.expiresAt), isTrue);
    });

    test('lanza FormatException si falta una clave obligatoria', () {
      final incomplete = <String, dynamic>{
        'id': 'i1',
        'email': 'a@x.com',
        'role': 'WORKER',
        'status': 'PENDING',
        // sin expires_at / created_at
      };

      expect(() => InvitationResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si un timestamp es inválido', () {
      final bad = <String, dynamic>{
        'id': 'i1',
        'email': 'a@x.com',
        'role': 'WORKER',
        'status': 'PENDING',
        'expires_at': 'no-es-fecha',
        'created_at': '2026-05-25T00:00:00Z',
      };

      expect(() => InvitationResp.fromJson(bad), throwsFormatException);
    });
  });
}
