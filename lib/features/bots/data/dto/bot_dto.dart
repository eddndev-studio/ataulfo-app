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
    this.disabledToolGroups = const <String>[],
    this.groupChatsAiDisabled = false,
    this.groupChatsFlowsDisabled = false,
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
    // Clave aditiva (override de permisos del bot): el backend la emite como
    // array; un server previo al campo no la manda ⇒ lista vacía. Se filtra a
    // strings por defensa de contrato.
    final groupsRaw = json['disabled_tool_groups'];
    final disabledToolGroups = groupsRaw is List
        ? groupsRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    // Gates de grupos: snake_case, como el resto del objeto bot del wire.
    // Aditivas y tolerantes: un server previo al campo, o un valor no-bool,
    // degradan a `false` (comportamiento actual) sin romper el parseo.
    final groupChatsAiDisabled = json['group_chats_ai_disabled'] is bool
        ? json['group_chats_ai_disabled'] as bool
        : false;
    final groupChatsFlowsDisabled = json['group_chats_flows_disabled'] is bool
        ? json['group_chats_flows_disabled'] as bool
        : false;
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
      disabledToolGroups: disabledToolGroups,
      groupChatsAiDisabled: groupChatsAiDisabled,
      groupChatsFlowsDisabled: groupChatsFlowsDisabled,
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
  final List<String> disabledToolGroups;
  final bool groupChatsAiDisabled;
  final bool groupChatsFlowsDisabled;
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
    this.disabledToolGroups,
    this.groupChatsAiDisabled,
    this.groupChatsFlowsDisabled,
  });

  final int version;
  final String? name;
  final bool? paused;
  final bool? aiDisabled;
  final Map<String, String>? variableValues;

  /// Tristate: null ⇒ se OMITE (no toca el override); `[]` ⇒ limpiar; `[..]` ⇒
  /// set. El bot SUMA grupos apagados sobre los de su plantilla (unión).
  final List<String>? disabledToolGroups;

  /// Gates de grupos (tristate por omisión): null ⇒ se OMITE ("no tocar");
  /// presente ⇒ se aplica. Claves snake_case, como el resto del objeto bot.
  final bool? groupChatsAiDisabled;
  final bool? groupChatsFlowsDisabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (name != null) 'name': name,
    if (paused != null) 'paused': paused,
    if (aiDisabled != null) 'ai_disabled': aiDisabled,
    if (variableValues != null) 'variable_values': variableValues,
    if (disabledToolGroups != null) 'disabled_tool_groups': disabledToolGroups,
    if (groupChatsAiDisabled != null)
      'group_chats_ai_disabled': groupChatsAiDisabled,
    if (groupChatsFlowsDisabled != null)
      'group_chats_flows_disabled': groupChatsFlowsDisabled,
    'version': version,
  };
}

/// Respuesta de `GET /bots/:id/variables`
/// (`ataulfo-go/internal/adapters/httpbots/dto.go` `botVariablesResp`). El
/// editor de variables la consume para PRECARGAR los overrides guardados.
///
/// `variable_values` SIEMPRE es objeto (nunca `null`): un bot sin overrides
/// emite `{}`. Se valida fail-loud que sea un map de strings — drift del
/// contrato no se degrada en silencio.
class BotVariablesResp {
  const BotVariablesResp({
    required this.version,
    required this.templateId,
    required this.values,
  });

  factory BotVariablesResp.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final templateId = json['template_id'];
    final raw = json['variable_values'];
    if (version is! int || templateId is! String || raw is! Map) {
      throw const FormatException(
        'botVariablesResp: clave obligatoria ausente',
      );
    }
    final values = <String, String>{};
    for (final entry in raw.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k is! String || v is! String) {
        throw const FormatException(
          'botVariablesResp: variable_values debe ser map<string,string>',
        );
      }
      values[k] = v;
    }
    return BotVariablesResp(
      version: version,
      templateId: templateId,
      values: values,
    );
  }

  final int version;
  final String templateId;
  final Map<String, String> values;
}

/// Body de `POST /bots/:id/clone` (`cloneReq`). El cliente provee el `name`
/// del clon; el dominio no inventa sufijos. El clon nace con id, canal y
/// plantilla heredados pero `version` reiniciada y sin identifier.
class BotCloneReq {
  const BotCloneReq({required this.name});

  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};
}
