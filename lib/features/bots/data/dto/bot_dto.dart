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

/// Body de `PUT /bots/:id` (`ataulfo-go/internal/adapters/httpbots/dto.go`
/// `putReq`). Tristate POR OMISIÓN: un campo null se OMITE del JSON ("no
/// tocar"); presente se aplica. `version` SIEMPRE viaja (CAS optimista).
///
/// `channel` NUNCA viaja (I-B3: el canal es inmutable tras crear; el backend
/// lo enforca por ausencia del campo, no por guard). `identifier` tampoco:
/// es create-only.
///
/// `variableValues` se serializa como objeto JSON: `{}` (vaciar overrides) o
/// `{...}`; **jamás `null`** — el backend rechaza `variable_values:null` con
/// 422. Por eso un null aquí se OMITE (no se serializa la clave).
class BotUpdateReq {
  const BotUpdateReq({
    required this.version,
    this.name,
    this.paused,
    this.aiDisabled,
    this.variableValues,
  });

  final int version;
  final String? name;
  final bool? paused;
  final bool? aiDisabled;
  final Map<String, String>? variableValues;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (name != null) 'name': name,
    if (paused != null) 'paused': paused,
    if (aiDisabled != null) 'ai_disabled': aiDisabled,
    if (variableValues != null) 'variable_values': variableValues,
    'version': version,
  };
}

/// Body de `POST /bots/:id/clone` (`cloneReq`). El cliente provee el `name`
/// del clon; el dominio no inventa sufijos. El clon nace con id, canal y
/// plantilla heredados pero `version` reiniciada y sin identifier.
class BotCloneReq {
  const BotCloneReq({required this.name});

  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};
}
