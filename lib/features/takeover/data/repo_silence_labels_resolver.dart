import '../../bots/domain/repositories/bots_repository.dart';
import '../../templates/domain/repositories/templates_repository.dart';
import '../domain/silence_labels_resolver.dart';

/// Resuelve las etiquetas de silencio efectivas de un bot vía su plantilla:
/// bot → templateId → AIConfig.silenceLabelIds. Las etiquetas de silencio son
/// de la plantilla (no hay override por bot), así que basta leer la plantilla.
class RepoSilenceLabelsResolver implements SilenceLabelsResolver {
  RepoSilenceLabelsResolver({
    required BotsRepository bots,
    required TemplatesRepository templates,
  }) : _bots = bots,
       _templates = templates;

  final BotsRepository _bots;
  final TemplatesRepository _templates;

  @override
  Future<List<String>> forBot(String botId) async {
    final bot = await _bots.byId(botId);
    final tpl = await _templates.byId(bot.templateId);
    return tpl.ai.silenceLabelIds;
  }
}
