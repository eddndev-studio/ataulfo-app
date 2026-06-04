import '../../domain/entities/member.dart';
import '../dto/member_dto.dart';

/// Traduce el DTO del wire (GET /workspace/members) a la entidad de dominio.
///
/// Pura para que cualquier llamador (datasource, test) la componga sin estado.
/// Vive en `data/` porque conoce el shape del wire; el dominio no.
class MembersMapper {
  const MembersMapper._();

  static Member respToEntity(MemberResp resp) => Member(
    id: resp.id,
    userId: resp.userId,
    email: resp.email,
    emailVerified: resp.emailVerified,
    role: resp.role,
  );
}
