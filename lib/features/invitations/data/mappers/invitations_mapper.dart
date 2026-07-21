import '../../domain/entities/invitation.dart';
import '../dto/invitation_dto.dart';

/// Traduce el DTO del wire a la entidad de dominio. Pura y sin estado.
class InvitationsMapper {
  const InvitationsMapper._();

  static Invitation respToEntity(InvitationResp resp) => Invitation(
    id: resp.id,
    email: resp.email,
    role: resp.role,
    status: resp.status,
    botIds: resp.botIds,
    expiresAt: resp.expiresAt,
    createdAt: resp.createdAt,
  );
}
