import '../../domain/entities/entitlement.dart';
import '../dto/entitlement_dto.dart';

/// Traduce el DTO del wire (GET /workspace/billing) a la entidad de dominio.
///
/// Pura para que cualquier llamador (datasource, test) la componga sin
/// estado. Vive en `data/` porque conoce el shape del wire; el dominio no.
class EntitlementMapper {
  const EntitlementMapper._();

  static Entitlement dtoToEntity(EntitlementDto dto) => Entitlement(
    planCode: dto.planCode,
    status: dto.status,
    usedConversations: dto.usedConversations,
    conversationCap: dto.conversationCap,
    withinQuota: dto.withinQuota,
    quotaExceeded: dto.quotaExceeded,
    storageUsedMb: dto.storageUsedMb,
    storageQuotaMb: dto.storageQuotaMb,
    // El wire trae lista (orden del backend); el consumo cliente es
    // pertenencia ("¿este proveedor es elegible?"), semántica de set.
    eligibleProviders: dto.eligibleProviders.toSet(),
    features: dto.features,
  );
}
