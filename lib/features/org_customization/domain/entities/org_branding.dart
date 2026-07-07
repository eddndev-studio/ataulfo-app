/// Estado de la marca de documentos de la organización, proyectado por el
/// backend (`GET /workspace/organization/branding`). El logo aparece en el
/// membrete de los PDF que genera el asistente.
class OrgBranding {
  const OrgBranding({
    required this.configured,
    required this.customTex,
    required this.hasLogo,
    required this.logoUrl,
    required this.logoContentType,
  });

  /// Hay fila de marca guardada (estructurada o de autor).
  final bool configured;

  /// La marca guardada trae una plantilla de AUTOR (el asistente la
  /// personalizó). Cambiar el logo desde la app la reemplaza por la marca
  /// estándar con el logo — la UI confirma antes de pisar.
  final bool customTex;

  /// Hay un logo guardado.
  final bool hasLogo;

  /// URL firmada (efímera) del preview del logo. Vacía si no hay logo o si
  /// la firma falló (best-effort del backend): el preview degrada, la marca
  /// guardada sigue intacta.
  final String logoUrl;

  /// Content-type del logo guardado (`image/png` | `image/jpeg`).
  final String logoContentType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrgBranding &&
        other.configured == configured &&
        other.customTex == customTex &&
        other.hasLogo == hasLogo &&
        other.logoUrl == logoUrl &&
        other.logoContentType == logoContentType;
  }

  @override
  int get hashCode =>
      Object.hash(configured, customTex, hasLogo, logoUrl, logoContentType);
}
