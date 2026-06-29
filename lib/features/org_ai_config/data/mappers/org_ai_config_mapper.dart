import '../../../templates/data/mappers/templates_mapper.dart';
import '../../domain/entities/org_ai_config.dart';
import '../dto/org_ai_config_dto.dart';

/// Traduce el DTO del wire de `/org/ai-config` a la entidad de dominio. Pura.
/// El bloque `defaults` se mapea con [TemplatesMapper.aiConfigDtoToEntity] —
/// la misma traducción que usa la página de IA de la plantilla.
class OrgAiConfigMapper {
  const OrgAiConfigMapper._();

  static OrgAiConfig respToEntity(OrgAiConfigResp resp) => OrgAiConfig(
    hosts: resp.hosts,
    defaults: TemplatesMapper.aiConfigDtoToEntity(resp.defaults),
  );
}
