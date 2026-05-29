/// DTO de un Flow del wire (ver `flowResp` en
/// `ataulfo-go/internal/adapters/httpflows/dto.go`).
///
/// Espejo 1:1 del shape canónico: identidad + nombre + gates de
/// comportamiento (`cooldownMs`, `usageLimit`, `excludesFlows`) +
/// `version` (CAS optimista). `createdAt` / `updatedAt` quedan fuera
/// — ninguna superficie de UI los consume hoy.
///
/// Fail-loud por campo: si el wire omite un valor canónico, lanzamos
/// `FormatException`. El backend siempre serializa `excludesFlows`
/// como `[]` (no null) por contrato; un null aquí es drift.
class FlowResp {
  const FlowResp({
    required this.id,
    required this.templateId,
    required this.name,
    required this.isActive,
    required this.version,
    required this.cooldownMs,
    required this.usageLimit,
    required this.excludesFlows,
  });

  factory FlowResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final templateId = json['templateId'];
    final name = json['name'];
    final isActive = json['isActive'];
    final version = json['version'];
    final cooldownMs = json['cooldownMs'];
    final usageLimit = json['usageLimit'];
    final excludesRaw = json['excludesFlows'];
    if (id is! String ||
        templateId is! String ||
        name is! String ||
        isActive is! bool ||
        version is! int ||
        cooldownMs is! int ||
        usageLimit is! int ||
        excludesRaw is! List<dynamic>) {
      throw const FormatException('flowResp: clave obligatoria ausente');
    }
    final excludes = <String>[];
    for (final raw in excludesRaw) {
      if (raw is! String) {
        throw const FormatException(
          'flowResp: excludesFlows debe ser lista de string',
        );
      }
      excludes.add(raw);
    }
    return FlowResp(
      id: id,
      templateId: templateId,
      name: name,
      isActive: isActive,
      version: version,
      cooldownMs: cooldownMs,
      usageLimit: usageLimit,
      excludesFlows: excludes,
    );
  }

  final String id;
  final String templateId;
  final String name;
  final bool isActive;
  final int version;
  final int cooldownMs;
  final int usageLimit;
  final List<String> excludesFlows;
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
