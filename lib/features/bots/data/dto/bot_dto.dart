/// DTO del wire S04 (`ataulfo-go/internal/adapters/httpbots/dto.go:52`).
///
/// Cualquier nombre `snake_case` vive aquí; el dominio expone `camelCase`
/// vía mappers. `identifier` se preserva nullable porque el handler usa
/// `omitempty` cuando el bot todavía no fue etiquetado/pareado.
class BotResp {
  const BotResp({
    required this.id,
    required this.orgId,
    required this.templateId,
    required this.name,
    required this.channel,
    required this.identifier,
    required this.version,
    required this.paused,
    required this.aiDisabled,
  });

  factory BotResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final orgId = json['org_id'];
    final templateId = json['template_id'];
    final name = json['name'];
    final channel = json['channel'];
    final identifier = json['identifier'];
    final version = json['version'];
    final paused = json['paused'];
    final aiDisabled = json['ai_disabled'];
    if (id is! String ||
        orgId is! String ||
        templateId is! String ||
        name is! String ||
        channel is! String ||
        version is! int ||
        paused is! bool ||
        aiDisabled is! bool) {
      throw const FormatException('botResp: clave obligatoria ausente');
    }
    if (identifier != null && identifier is! String) {
      throw const FormatException('botResp: identifier no es String ni null');
    }
    return BotResp(
      id: id,
      orgId: orgId,
      templateId: templateId,
      name: name,
      channel: channel,
      identifier: identifier as String?,
      version: version,
      paused: paused,
      aiDisabled: aiDisabled,
    );
  }

  final String id;
  final String orgId;
  final String templateId;
  final String name;
  final String channel;
  final String? identifier;
  final int version;
  final bool paused;
  final bool aiDisabled;
}
