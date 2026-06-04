import 'package:ataulfo/features/auth/data/dto/login_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginReq', () {
    test('serializa email y password en snake_case del wire', () {
      const req = LoginReq(email: 'op@example.com', password: 'hunter2-secret');

      expect(req.toJson(), <String, dynamic>{
        'email': 'op@example.com',
        'password': 'hunter2-secret',
      });
    });
  });

  group('TokenResp', () {
    test('parsea las 4 claves del contrato S02 tal cual', () {
      final json = <String, dynamic>{
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.access.sig',
        'refresh_token': 'rt-32-bytes-base64url',
        'token_type': 'Bearer',
        'expires_in': 900,
      };

      final resp = TokenResp.fromJson(json);

      expect(resp.accessToken, 'eyJhbGciOiJIUzI1NiJ9.access.sig');
      expect(resp.refreshToken, 'rt-32-bytes-base64url');
      expect(resp.tokenType, 'Bearer');
      expect(resp.expiresIn, 900);
    });

    test('lanza FormatException si falta una clave obligatoria', () {
      final incomplete = <String, dynamic>{
        'access_token': 'a',
        'refresh_token': 'r',
        'token_type': 'Bearer',
        // expires_in ausente
      };

      expect(() => TokenResp.fromJson(incomplete), throwsFormatException);
    });
  });

  group('MeResp', () {
    test('parsea las 4 claves del contrato S02 /auth/me', () {
      final json = <String, dynamic>{
        'user_id': 'u-123',
        'org_id': 'o-456',
        'role': 'OWNER',
        'email': 'op@example.com',
      };

      final resp = MeResp.fromJson(json);

      expect(resp.userId, 'u-123');
      expect(resp.orgId, 'o-456');
      expect(resp.role, 'OWNER');
      expect(resp.email, 'op@example.com');
    });

    test('lanza FormatException si falta role', () {
      final incomplete = <String, dynamic>{
        'user_id': 'u-1',
        'org_id': 'o-1',
        'email': 'op@example.com',
        // role ausente
      };

      expect(() => MeResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si falta email', () {
      // El backend post-S02 SIEMPRE devuelve email vivo (paga SELECT por
      // request). Email ausente es contrato roto, no estado vacío.
      final incomplete = <String, dynamic>{
        'user_id': 'u-1',
        'org_id': 'o-1',
        'role': 'OWNER',
        // email ausente
      };

      expect(() => MeResp.fromJson(incomplete), throwsFormatException);
    });

    test('lanza FormatException si una clave tiene tipo equivocado', () {
      final wrongType = <String, dynamic>{
        'user_id': 'u-1',
        'org_id': 42, // debería ser String
        'role': 'ADMIN',
        'email': 'op@example.com',
      };

      expect(() => MeResp.fromJson(wrongType), throwsFormatException);
    });

    test('emailVerified = false cuando la clave email_verified está ausente', () {
      // El campo viaja en un slice posterior del backend; mientras no esté
      // mergeado, su ausencia se tolera con default false (no es contrato roto).
      final json = <String, dynamic>{
        'user_id': 'u-1',
        'org_id': 'o-1',
        'role': 'OWNER',
        'email': 'op@example.com',
      };

      expect(MeResp.fromJson(json).emailVerified, isFalse);
    });

    test('emailVerified lee email_verified=true del wire', () {
      final json = <String, dynamic>{
        'user_id': 'u-1',
        'org_id': 'o-1',
        'role': 'OWNER',
        'email': 'op@example.com',
        'email_verified': true,
      };

      expect(MeResp.fromJson(json).emailVerified, isTrue);
    });
  });

  group('RegisterReq', () {
    test('serializa email y password en snake_case del wire', () {
      const req = RegisterReq(
        email: 'new@example.com',
        password: 's3cret-pass',
      );

      expect(req.toJson(), <String, dynamic>{
        'email': 'new@example.com',
        'password': 's3cret-pass',
      });
    });
  });

  group('VerifyEmailReq', () {
    test('serializa el token', () {
      const req = VerifyEmailReq(token: 'verif-tok-32');

      expect(req.toJson(), <String, dynamic>{'token': 'verif-tok-32'});
    });
  });

  group('VerifyEmailResp', () {
    test('parsea alreadyVerified (clave camelCase del wire)', () {
      final resp = VerifyEmailResp.fromJson(<String, dynamic>{
        'alreadyVerified': true,
      });

      expect(resp.alreadyVerified, isTrue);
    });

    test('lanza FormatException si alreadyVerified falta o no es bool', () {
      expect(
        () => VerifyEmailResp.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
      expect(
        () => VerifyEmailResp.fromJson(<String, dynamic>{'alreadyVerified': 1}),
        throwsFormatException,
      );
    });
  });

  group('ForgotPasswordReq', () {
    test('serializa el email', () {
      const req = ForgotPasswordReq(email: 'op@example.com');

      expect(req.toJson(), <String, dynamic>{'email': 'op@example.com'});
    });
  });

  group('ResetPasswordReq', () {
    test('serializa token y new_password en snake_case del wire', () {
      const req = ResetPasswordReq(token: 'reset-tok', newPassword: 'n3w-pass');

      expect(req.toJson(), <String, dynamic>{
        'token': 'reset-tok',
        'new_password': 'n3w-pass',
      });
    });
  });

  group('SwitchOrgReq', () {
    test('serializa org_id en snake_case del wire', () {
      const req = SwitchOrgReq(orgId: 'o-789');

      expect(req.toJson(), <String, dynamic>{'org_id': 'o-789'});
    });
  });

  group('AcceptInvitationReq', () {
    test('serializa el token', () {
      const req = AcceptInvitationReq(token: 'invite-tok');

      expect(req.toJson(), <String, dynamic>{'token': 'invite-tok'});
    });
  });
}
