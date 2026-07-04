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
    this.responseDelaySeconds = 0,
    this.silenceLabelIds = const <String>[],
    this.disabledToolGroups = const <String>[],
    this.followUpEnabled = false,
    this.followUpDelayMinutes = 0,
    this.followUpMaxAttempts = 0,
    this.subagentProvider,
    this.subagentModel,
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
    // Clave aditiva (ventana de acumulación): un backend previo al campo no
    // la manda y el cliente degrada a 0 — responder de inmediato. Mismo
    // trato tolerante que `counts`, a diferencia de las claves fundacionales.
    final delayRaw = json['response_delay_seconds'];
    // Clave aditiva (etiquetas de silencio): el backend la omite (omitempty)
    // cuando no hay ninguna; ausente ⇒ lista vacía. Se filtra a strings por
    // defensa de contrato (un elemento no-string no es un id de etiqueta).
    final silenceRaw = json['silence_label_ids'];
    final silenceLabelIds = silenceRaw is List
        ? silenceRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    // Clave aditiva (permisos de herramientas): el backend la omite (omitempty)
    // cuando no apaga ningún grupo; ausente ⇒ lista vacía (todo habilitado).
    final groupsRaw = json['disabled_tool_groups'];
    final disabledToolGroups = groupsRaw is List
        ? groupsRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    // Claves aditivas del seguimiento por inactividad: un backend previo no
    // las manda ⇒ apagado con knobs en cero (inerte).
    final followUpEnabledRaw = json['follow_up_enabled'];
    final followUpDelayRaw = json['follow_up_delay_minutes'];
    final followUpAttemptsRaw = json['follow_up_max_attempts'];
    // Claves aditivas (modelo de subagentes): un backend previo no las manda
    // (o las manda vacías) ⇒ null = heredar el modelo principal. Una cadena
    // vacía se trata igual que ausente; el par viaja junto (ambos o ninguno).
    final subagentProviderRaw = json['subagent_provider'];
    final subagentModelRaw = json['subagent_model'];
    final subagentProvider =
        subagentProviderRaw is String && subagentProviderRaw.isNotEmpty
        ? subagentProviderRaw
        : null;
    final subagentModel =
        subagentModelRaw is String && subagentModelRaw.isNotEmpty
        ? subagentModelRaw
        : null;
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
      responseDelaySeconds: delayRaw is int ? delayRaw : 0,
      silenceLabelIds: silenceLabelIds,
      disabledToolGroups: disabledToolGroups,
      followUpEnabled: followUpEnabledRaw is bool ? followUpEnabledRaw : false,
      followUpDelayMinutes: followUpDelayRaw is int ? followUpDelayRaw : 0,
      followUpMaxAttempts: followUpAttemptsRaw is int ? followUpAttemptsRaw : 0,
      subagentProvider: subagentProvider,
      subagentModel: subagentModel,
    );
  }

  final bool enabled;
  final String provider;
  final String model;
  final double temperature;
  final String thinkingLevel;
  final String systemPrompt;
  final int contextMessages;
  final int responseDelaySeconds;
  final List<String> silenceLabelIds;
  final List<String> disabledToolGroups;
  final bool followUpEnabled;
  final int followUpDelayMinutes;
  final int followUpMaxAttempts;

  /// Wire crudo del proveedor del modelo de subagentes (`AIProvider` sin
  /// traducir). null = ausente/vacío ⇒ heredar. Viaja emparejado con
  /// [subagentModel]: ambos presentes o ambos null.
  final String? subagentProvider;

  /// Id lógico del modelo de subagentes. null = heredar el modelo principal.
  final String? subagentModel;
}
