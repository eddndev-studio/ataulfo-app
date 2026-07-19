enum ResourceKind {
  knowledgeDocument,
  file,
  media,
  product,
  unknown;

  factory ResourceKind.fromWire(String value) => switch (value) {
    'knowledge_document' => ResourceKind.knowledgeDocument,
    'file' => ResourceKind.file,
    'media' => ResourceKind.media,
    'product' => ResourceKind.product,
    _ => ResourceKind.unknown,
  };
}

enum AssistantResourceScope {
  all,
  selected;

  factory AssistantResourceScope.fromWire(String value) =>
      value.toUpperCase() == 'SELECTED'
      ? AssistantResourceScope.selected
      : AssistantResourceScope.all;

  String get wire => name.toUpperCase();
}

/// Identidad común de la Biblioteca. El contenido sigue viviendo en su
/// dominio tipado; esta entidad sólo permite descubrirlo y asociarlo.
class ResourceItem {
  const ResourceItem({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.name,
    required this.active,
    required this.sharedByDefault,
    required this.indexable,
    required this.sendable,
    required this.version,
  });

  final String id;
  final String sourceId;
  final ResourceKind kind;
  final String name;
  final bool active;
  final bool sharedByDefault;
  final bool indexable;
  final bool sendable;
  final int version;
}

class ResourceSnapshot {
  const ResourceSnapshot({
    required this.revision,
    required this.resources,
    this.scope,
  });

  final int revision;
  final List<ResourceItem> resources;
  final AssistantResourceScope? scope;
}
