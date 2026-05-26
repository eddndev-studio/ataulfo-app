import '../../domain/entities/membership.dart';
import '../dto/membership_dto.dart';

/// Traduce el DTO del wire (GET /auth/memberships) a la entidad de dominio.
///
/// Pura para que cualquier llamador (datasource, test) la componga sin
/// estado. Vive en `data/` porque conoce el shape del wire; el dominio no.
class MembershipsMapper {
  const MembershipsMapper._();

  static Membership respToEntity(MembershipResp resp) =>
      Membership(orgId: resp.orgId, orgName: resp.orgName, role: resp.role);
}
