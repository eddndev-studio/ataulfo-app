import 'package:ataulfo/features/auth/data/dto/login_dto.dart';
import 'package:ataulfo/features/auth/data/mappers/auth_mapper.dart';
import 'package:ataulfo/features/auth/domain/entities/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthTokens', () {
    test('expone los 4 campos del par emitido por S02', () {
      const tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'Bearer',
        expiresInSeconds: 900,
      );

      expect(tokens.accessToken, 'access');
      expect(tokens.refreshToken, 'refresh');
      expect(tokens.tokenType, 'Bearer');
      expect(tokens.expiresInSeconds, 900);
    });

    test('dos AuthTokens con misma data son iguales (value-type)', () {
      const a = AuthTokens(
        accessToken: 'x',
        refreshToken: 'y',
        tokenType: 'Bearer',
        expiresInSeconds: 60,
      );
      const b = AuthTokens(
        accessToken: 'x',
        refreshToken: 'y',
        tokenType: 'Bearer',
        expiresInSeconds: 60,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('AuthMapper.tokenRespToEntity', () {
    test('TokenResp → AuthTokens preserva los 4 campos', () {
      const resp = TokenResp(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'Bearer',
        expiresIn: 900,
      );

      final tokens = AuthMapper.tokenRespToEntity(resp);

      expect(
        tokens,
        const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );
    });
  });
}
