import '../../domain/entities/catalog_appearance.dart';
import '../../domain/entities/public_catalog_settings.dart';

/// DTO del wire de `/workspace/organization/public-catalog`. `enabled` es
/// obligatorio (bool); `slug` y `url` son null cuando la org nunca acuñó slug.
/// Un `enabled` ausente o de otro tipo es wire roto.
///
/// `design` y `accent` son aditivos: un backend viejo puede no mandarlos aún, y
/// una caché vieja puede traer un valor que ya no existe. Ambos casos caen al
/// default vía [CatalogDesign.fromWire] / [CatalogAccent.fromWire] (fail-open):
/// NUNCA lanzan FormatException por un valor de apariencia ausente o
/// desconocido.
class PublicCatalogSettingsDto {
  const PublicCatalogSettingsDto({
    required this.enabled,
    required this.slug,
    required this.url,
    required this.design,
    required this.accent,
  });

  factory PublicCatalogSettingsDto.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException(
        'public-catalog: "enabled" ausente o inválido',
      );
    }
    return PublicCatalogSettingsDto(
      enabled: enabled,
      slug: json['slug'] as String?,
      url: json['url'] as String?,
      design: CatalogDesign.fromWire(json['design']),
      accent: CatalogAccent.fromWire(json['accent']),
    );
  }

  final bool enabled;
  final String? slug;
  final String? url;
  final CatalogDesign design;
  final CatalogAccent accent;

  PublicCatalogSettings toEntity() => PublicCatalogSettings(
    enabled: enabled,
    slug: slug,
    url: url,
    design: design,
    accent: accent,
  );
}
