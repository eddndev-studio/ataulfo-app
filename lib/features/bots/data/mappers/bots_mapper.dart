import '../../domain/entities/bot.dart';
import '../../domain/entities/bot_variables_snapshot.dart';
import '../dto/bot_dto.dart';

/// Traduce DTOs del wire S04 a entidades de dominio.
///
/// Es pura: cualquier llamador (datasource, test, futura cache) la compone
/// sin estado. La traducción del canal usa `BotChannel.fromWire` (fail-loud
/// ante drift del backend).
class BotsMapper {
  const BotsMapper._();

  static Bot botRespToEntity(BotResp resp) => Bot(
    id: resp.id,
    orgId: resp.orgId,
    templateId: resp.templateId,
    name: resp.name,
    channel: BotChannel.fromWire(resp.channel),
    identifier: resp.identifier,
    version: resp.version,
    paused: resp.paused,
    aiDisabled: resp.aiDisabled,
    disabledToolGroups: resp.disabledToolGroups,
  );

  static BotVariablesSnapshot variablesSnapshotFromResp(
    BotVariablesResp resp,
  ) => BotVariablesSnapshot(
    version: resp.version,
    templateId: resp.templateId,
    values: resp.values,
  );
}
