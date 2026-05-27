/// DTO de un Flow del listado `GET /templates/{id}/flows` (ver
/// `flowResp` en `agentic-go/internal/adapters/httpflows/dto.go`).
///
/// Sólo modela el subconjunto de campos que la entity consume hoy
/// (`{id, templateId, name, isActive, version}`). El wire trae además
/// `cooldownMs`, `usageLimit`, `excludesFlows`, `createdAt`, `updatedAt`
/// — se ignoran en F1 para no introducir mapeo muerto; los habilitará
/// el editor de gates cuando los necesite.
class FlowResp {
  const FlowResp({
    required this.id,
    required this.templateId,
    required this.name,
    required this.isActive,
    required this.version,
  });

  factory FlowResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final templateId = json['templateId'];
    final name = json['name'];
    final isActive = json['isActive'];
    final version = json['version'];
    if (id is! String ||
        templateId is! String ||
        name is! String ||
        isActive is! bool ||
        version is! int) {
      throw const FormatException('flowResp: clave obligatoria ausente');
    }
    return FlowResp(
      id: id,
      templateId: templateId,
      name: name,
      isActive: isActive,
      version: version,
    );
  }

  final String id;
  final String templateId;
  final String name;
  final bool isActive;
  final int version;
}

/// Wrapper de la lista `GET /templates/{id}/flows` → `{items:[...]}`.
class ListFlowsResp {
  const ListFlowsResp({required this.items});

  factory ListFlowsResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('listFlowsResp: items ausente o no es lista');
    }
    return ListFlowsResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(FlowResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<FlowResp> items;
}
