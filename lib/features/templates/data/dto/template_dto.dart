/// DTO del wire S03/S12
/// (`ataulfo-go/internal/adapters/httptemplates/dto.go`).
///
/// Cualquier nombre `snake_case` vive aquí; el dominio expone `camelCase`
/// vía mappers. AiConfigDto está anidado en el campo `ai` de TemplateResp;
/// se modela como tipo aparte porque su parser tiene su propia política de
/// errores (FormatException por clave faltante) y permite testear las dos
/// capas por separado.
class TemplateResp {
  const TemplateResp({
    required this.id,
    required this.orgId,
    required this.name,
    required this.version,
    required this.ai,
    this.counts,
  });

  factory TemplateResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final orgId = json['org_id'];
    final name = json['name'];
    final version = json['version'];
    final ai = json['ai'];
    if (id is! String ||
        orgId is! String ||
        name is! String ||
        version is! int ||
        ai is! Map<String, dynamic>) {
      throw const FormatException('templateResp: clave obligatoria ausente');
    }
    // `counts` es aditivo y solo viaja en GET /templates. Ausente ⇒ null
    // (entidad única); presente pero malformado ⇒ FormatException (igual
    // disciplina fail-loud que el resto del DTO).
    final countsRaw = json['counts'];
    final counts = countsRaw is Map<String, dynamic>
        ? TemplateCountsDto.fromJson(countsRaw)
        : null;
    return TemplateResp(
      id: id,
      orgId: orgId,
      name: name,
      version: version,
      ai: AiConfigDto.fromJson(ai),
      counts: counts,
    );
  }

  final String id;
  final String orgId;
  final String name;
  final int version;
  final AiConfigDto ai;
  final TemplateCountsDto? counts;
}

/// DTO del objeto `counts` de templateResp (solo en el listado). Conteo de
/// agregados hijos de la Template. Claves enteras y obligatorias cuando el
/// objeto está presente.
class TemplateCountsDto {
  const TemplateCountsDto({
    required this.bots,
    required this.flows,
    required this.variables,
  });

  factory TemplateCountsDto.fromJson(Map<String, dynamic> json) {
    final bots = json['bots'];
    final flows = json['flows'];
    final variables = json['variables'];
    if (bots is! int || flows is! int || variables is! int) {
      throw const FormatException('templateCounts: clave obligatoria ausente');
    }
    return TemplateCountsDto(bots: bots, flows: flows, variables: variables);
  }

  final int bots;
  final int flows;
  final int variables;
}

/// DTO del objeto `ai` anidado en templateResp (S12).
class AiConfigDto {
  const AiConfigDto({
    required this.enabled,
    required this.provider,
    required this.model,
    required this.temperature,
    required this.thinkingLevel,
    required this.systemPrompt,
    required this.contextMessages,
  });

  factory AiConfigDto.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final provider = json['provider'];
    final model = json['model'];
    final temperatureRaw = json['temperature'];
    final thinkingLevel = json['thinking_level'];
    final systemPrompt = json['system_prompt'];
    final contextMessages = json['context_messages'];
    if (enabled is! bool ||
        provider is! String ||
        model is! String ||
        temperatureRaw is! num ||
        thinkingLevel is! String ||
        systemPrompt is! String ||
        contextMessages is! int) {
      throw const FormatException('aiConfigDTO: clave obligatoria ausente');
    }
    return AiConfigDto(
      enabled: enabled,
      provider: provider,
      model: model,
      // El JSON puede entregar `1` (int) en vez de `1.0`; el cliente
      // normaliza a double para preservar el contrato del dominio.
      temperature: temperatureRaw.toDouble(),
      thinkingLevel: thinkingLevel,
      systemPrompt: systemPrompt,
      contextMessages: contextMessages,
    );
  }

  final bool enabled;
  final String provider;
  final String model;
  final double temperature;
  final String thinkingLevel;
  final String systemPrompt;
  final int contextMessages;
}
