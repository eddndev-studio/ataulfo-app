/// Ajustes del catálogo público de la org (`/workspace/organization/
/// public-catalog`). Cuando la org nunca acuñó un slug, [slug] y [url] son
/// null; [url] es la página del sitio, derivada del slug por el backend.
class PublicCatalogSettings {
  const PublicCatalogSettings({
    required this.enabled,
    required this.slug,
    required this.url,
  });

  final bool enabled;
  final String? slug;
  final String? url;

  PublicCatalogSettings copyWith({bool? enabled}) => PublicCatalogSettings(
    enabled: enabled ?? this.enabled,
    slug: slug,
    url: url,
  );

  @override
  bool operator ==(Object other) =>
      other is PublicCatalogSettings &&
      other.enabled == enabled &&
      other.slug == slug &&
      other.url == url;

  @override
  int get hashCode => Object.hash(enabled, slug, url);
}
