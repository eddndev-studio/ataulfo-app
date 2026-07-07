import '../../domain/entities/org_branding.dart';
import '../dto/org_branding_dto.dart';

/// wire ⇄ dominio del módulo de personalización. El DTO es 1:1 con la
/// entidad hoy; el mapper existe para que el wire pueda divergir sin tocar
/// dominio ni presentación.
abstract final class OrgBrandingMapper {
  static OrgBranding respToEntity(OrgBrandingResp resp) {
    return OrgBranding(
      configured: resp.configured,
      customTex: resp.customTex,
      hasLogo: resp.hasLogo,
      logoUrl: resp.logoUrl,
      logoContentType: resp.logoContentType,
    );
  }
}
