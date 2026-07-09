import 'catalog_appearance.dart';

/// Ajustes del catálogo público de la org (`/workspace/organization/
/// public-catalog`). Cuando la org nunca acuñó un slug, [slug] y [url] son
/// null; [url] es la página del sitio, derivada del slug por el backend.
/// [design] y [accent] son la apariencia elegida (siempre concretos: el mapeo
/// del wire ya resolvió ausencias/valores desconocidos a su default).
class PublicCatalogSettings {
  const PublicCatalogSettings({
    required this.enabled,
    required this.slug,
    required this.url,
    required this.design,
    required this.accent,
  });

  final bool enabled;
  final String? slug;
  final String? url;
  final CatalogDesign design;
  final CatalogAccent accent;

  PublicCatalogSettings copyWith({
    bool? enabled,
    CatalogDesign? design,
    CatalogAccent? accent,
  }) => PublicCatalogSettings(
    enabled: enabled ?? this.enabled,
    slug: slug,
    url: url,
    design: design ?? this.design,
    accent: accent ?? this.accent,
  );

  @override
  bool operator ==(Object other) =>
      other is PublicCatalogSettings &&
      other.enabled == enabled &&
      other.slug == slug &&
      other.url == url &&
      other.design == design &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(enabled, slug, url, design, accent);
}
