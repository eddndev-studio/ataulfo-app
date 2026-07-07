/// DTO del wire de `GET /workspace/organization/branding` (snake_case, como
/// el resto del workspace). Claves ausentes caen a defaults seguros: un
/// backend viejo sin el campo no debe romper el módulo.
class OrgBrandingResp {
  const OrgBrandingResp({
    required this.configured,
    required this.customTex,
    required this.hasLogo,
    required this.logoUrl,
    required this.logoContentType,
  });

  factory OrgBrandingResp.fromJson(Map<String, dynamic> json) {
    return OrgBrandingResp(
      configured: json['configured'] as bool? ?? false,
      customTex: json['custom_tex'] as bool? ?? false,
      hasLogo: json['has_logo'] as bool? ?? false,
      logoUrl: json['logo_url'] as String? ?? '',
      logoContentType: json['logo_content_type'] as String? ?? '',
    );
  }

  final bool configured;
  final bool customTex;
  final bool hasLogo;
  final String logoUrl;
  final String logoContentType;
}
