import '../../domain/entities/template.dart';
import '../dto/template_dto.dart';

/// Traduce DTOs del wire S03/S12 a entidades de dominio. Es pura:
/// cualquier llamador (datasource, test, futura cache) la compone sin
/// estado. La traducción de proveedor / thinking level usa
/// `AIProvider.fromWire` / `ThinkingLevel.fromWire` (fail-loud ante drift
/// del backend — el ArgumentError se propaga sin envolver).
class TemplatesMapper {
  const TemplatesMapper._();

  static AIConfig aiConfigDtoToEntity(AiConfigDto dto) => AIConfig(
    enabled: dto.enabled,
    provider: AIProvider.fromWire(dto.provider),
    model: dto.model,
    temperature: dto.temperature,
    thinkingLevel: ThinkingLevel.fromWire(dto.thinkingLevel),
    systemPrompt: dto.systemPrompt,
    contextMessages: dto.contextMessages,
    responseDelaySeconds: dto.responseDelaySeconds,
    silenceLabelIds: dto.silenceLabelIds,
    disabledToolGroups: dto.disabledToolGroups,
    followUpEnabled: dto.followUpEnabled,
    followUpDelayMinutes: dto.followUpDelayMinutes,
    followUpMaxAttempts: dto.followUpMaxAttempts,
    subagent: _subagentDtoToEntity(dto),
  );

  /// Modelo de subagentes: presente solo si el par proveedor+modelo viaja
  /// completo. `AIProvider.fromWire` es fail-loud ante un proveedor que el
  /// cliente no reconoce (mismo trato que el proveedor principal). Un modelo
  /// sin proveedor (o viceversa) se ignora — el par es atómico.
  static SubagentModel? _subagentDtoToEntity(AiConfigDto dto) {
    final provider = dto.subagentProvider;
    final model = dto.subagentModel;
    if (provider == null || model == null) return null;
    return SubagentModel(provider: AIProvider.fromWire(provider), model: model);
  }

  /// Serializa AIConfig al objeto JSON del wire (claves snake_case). Es la
  /// inversa de `aiConfigDtoToEntity` y la fuente ÚNICA de la serialización:
  /// la consumen el PUT de templates (`ai`) y el de la config de IA de la org
  /// (`defaults`), para que ambas formas no deriven por separado.
  static Map<String, dynamic> aiConfigToWire(AIConfig ai) => <String, dynamic>{
    'enabled': ai.enabled,
    'provider': ai.provider.toWire(),
    'model': ai.model,
    'temperature': ai.temperature,
    'thinking_level': ai.thinkingLevel.toWire(),
    'system_prompt': ai.systemPrompt,
    'context_messages': ai.contextMessages,
    'response_delay_seconds': ai.responseDelaySeconds,
    'silence_label_ids': ai.silenceLabelIds,
    'disabled_tool_groups': ai.disabledToolGroups,
    'follow_up_enabled': ai.followUpEnabled,
    'follow_up_delay_minutes': ai.followUpDelayMinutes,
    'follow_up_max_attempts': ai.followUpMaxAttempts,
    // El modelo de subagentes viaja emparejado: ambas claves o ninguna.
    // Ausente ⇒ el backend hereda el modelo principal.
    if (ai.subagent != null) ...<String, dynamic>{
      'subagent_provider': ai.subagent!.provider.toWire(),
      'subagent_model': ai.subagent!.model,
    },
  };

  static Template templateRespToEntity(TemplateResp resp) => Template(
    id: resp.id,
    orgId: resp.orgId,
    name: resp.name,
    version: resp.version,
    ai: aiConfigDtoToEntity(resp.ai),
    counts: resp.counts == null ? null : _countsDtoToEntity(resp.counts!),
  );

  static TemplateCounts _countsDtoToEntity(TemplateCountsDto dto) =>
      TemplateCounts(
        bots: dto.bots,
        flows: dto.flows,
        variables: dto.variables,
      );
}
