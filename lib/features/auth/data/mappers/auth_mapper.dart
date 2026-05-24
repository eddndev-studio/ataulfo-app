import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/identity.dart';
import '../dto/login_dto.dart';

/// Traduce DTOs del wire S02 a entidades de dominio.
///
/// La función es pura para que cualquier llamador (datasource, test) la
/// componga sin estado. Mappers viven en `data/` porque conocen el shape
/// del wire; el dominio no.
class AuthMapper {
  const AuthMapper._();

  static AuthTokens tokenRespToEntity(TokenResp resp) => AuthTokens(
    accessToken: resp.accessToken,
    refreshToken: resp.refreshToken,
    tokenType: resp.tokenType,
    expiresInSeconds: resp.expiresIn,
  );

  static Identity meRespToEntity(MeResp resp) =>
      Identity(userId: resp.userId, orgId: resp.orgId, role: resp.role);
}
