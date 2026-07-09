import '../../domain/entities/public_catalog_settings.dart';

/// DTO del wire de `/workspace/organization/public-catalog`. `enabled` es
/// obligatorio (bool); `slug` y `url` son null cuando la org nunca acuñó slug.
/// Un `enabled` ausente o de otro tipo es wire roto.
class PublicCatalogSettingsDto {
  const PublicCatalogSettingsDto({
    required this.enabled,
    required this.slug,
    required this.url,
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
    );
  }

  final bool enabled;
  final String? slug;
  final String? url;

  PublicCatalogSettings toEntity() =>
      PublicCatalogSettings(enabled: enabled, slug: slug, url: url);
}
