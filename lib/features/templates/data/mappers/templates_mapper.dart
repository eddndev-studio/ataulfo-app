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
  );

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
