/// Familia de value objects de la configuración del motor IA. Vive en
/// `core/ai` porque es vocabulario COMPARTIDO entre features — la plantilla
/// la edita, los defaults de la org la heredan y el editor compartido de
/// ai_catalog la pinta — y lo compartido vive en `core/`, junto al catálogo
/// de grupos de herramientas cuyos ids llenan [AIConfig.disabledToolGroups].
/// `templates/domain/entities/template.dart` la re-exporta para sus
/// consumidores históricos.
library;

/// Proveedor LLM del motor IA (S12). Set cerrado: si el backend agrega uno
/// nuevo (p. ej. "ANTHROPIC") el cliente DEBE romper al parsear; degradar a
/// un "unknown" cosmético escondería drift de contrato y la UI mostraría
/// configuraciones imposibles de aplicar.
enum AIProvider {
  openai,
  gemini,
  minimax,
  deepseek,
  // GLM (Zhipu) y Kimi (Moonshot): familias open-weight servidas por los
  // hosts occidentales zero-retention del backend.
  glm,
  kimi,
  // Nemotron (NVIDIA): familia open-weight servida por los hosts occidentales
  // zero-retention del backend, igual que GLM/Kimi.
  nemotron;

  static AIProvider fromWire(String raw) => switch (raw) {
    'OPENAI' => AIProvider.openai,
    'GEMINI' => AIProvider.gemini,
    'MINIMAX' => AIProvider.minimax,
    'DEEPSEEK' => AIProvider.deepseek,
    'GLM' => AIProvider.glm,
    'KIMI' => AIProvider.kimi,
    'NEMOTRON' => AIProvider.nemotron,
    _ => throw ArgumentError.value(raw, 'AIProvider.fromWire'),
  };

  /// Inversa de `fromWire`: la presentación nunca toca strings del wire.
  /// Round-trip estructural: `AIProvider.fromWire(p.toWire()) == p` para
  /// todo `p` (mismo invariante que `BotChannel`).
  String toWire() => switch (this) {
    AIProvider.openai => 'OPENAI',
    AIProvider.gemini => 'GEMINI',
    AIProvider.minimax => 'MINIMAX',
    AIProvider.deepseek => 'DEEPSEEK',
    AIProvider.glm => 'GLM',
    AIProvider.kimi => 'KIMI',
    AIProvider.nemotron => 'NEMOTRON',
  };
}

/// Modelo con el que corren los subagentes que el bot delega vía
/// `spawn_agent` (S12). Value object: proveedor + id lógico del modelo,
/// siempre juntos (el invariante "ambos o ninguno" del wire se codifica
/// como este objeto nullable en [AIConfig.subagent] — `null` = heredar el
/// modelo principal).
class SubagentModel {
  const SubagentModel({required this.provider, required this.model});

  final AIProvider provider;
  final String model;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubagentModel &&
        other.provider == provider &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(provider, model);
}

/// Nivel de razonamiento del modelo (S12). Cada proveedor lo mapea a su
/// propia perilla (Gemini thinkingLevel / OpenAI reasoning_effort; MiniMax
/// razona nativamente y lo ignora). Política fail-loud igual que AIProvider.
enum ThinkingLevel {
  low,
  medium,
  high;

  static ThinkingLevel fromWire(String raw) => switch (raw) {
    'LOW' => ThinkingLevel.low,
    'MEDIUM' => ThinkingLevel.medium,
    'HIGH' => ThinkingLevel.high,
    _ => throw ArgumentError.value(raw, 'ThinkingLevel.fromWire'),
  };

  String toWire() => switch (this) {
    ThinkingLevel.low => 'LOW',
    ThinkingLevel.medium => 'MEDIUM',
    ThinkingLevel.high => 'HIGH',
  };
}

/// Comportamiento IA de una Template (S03 + S12). Value object: dos
/// instancias con misma data son iguales. `enabled` es el toggle heredable
/// por los Bots; la regla efectiva (enabled && !bot.aiDisabled) la resuelve
/// el motor del backend, no este value object.
class AIConfig {
  const AIConfig({
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
    this.subagent,
  });

  final bool enabled;
  final AIProvider provider;
  final String model;
  final double temperature;
  final ThinkingLevel thinkingLevel;
  final String systemPrompt;
  final int contextMessages;

  /// Ventana de acumulación del motor: segundos que espera desde el PRIMER
  /// mensaje del cliente antes de atender todo lo acumulado en una corrida.
  /// 0 = responder de inmediato. La ventana es fija (no se reinicia con
  /// mensajes posteriores); el backend la acota a 0..120.
  final int responseDelaySeconds;

  /// Ids de etiquetas de la organización ante cuya presencia en el chat el
  /// motor NO atiende el turno (gate de silencio: el humano toma el control).
  /// Vacío = ningún silenciamiento. El orden no es significativo, pero el
  /// backend lo conserva tal cual; la igualdad lo compara por posición.
  final List<String> silenceLabelIds;

  /// Deny-list de grupos de capacidad del agente IA que la plantilla apaga
  /// (ids de `ToolGroup`). Vacío = todos habilitados. El Bot puede sumar más
  /// grupos apagados (unión); el set efectivo lo resuelve el backend. Se guarda
  /// como ids crudos (tolerante a un grupo futuro), igual que silenceLabelIds.
  final List<String> disabledToolGroups;

  /// Seguimiento automático por inactividad (S12/S27): con el toggle activo,
  /// si el cliente no responde en `followUpDelayMinutes` tras una respuesta
  /// del bot, el motor despierta en modo seguimiento (hasta
  /// `followUpMaxAttempts` por ciclo). Apagado, los knobs son inertes (cero
  /// en filas legacy).
  final bool followUpEnabled;
  final int followUpDelayMinutes;
  final int followUpMaxAttempts;

  /// Modelo con el que corren los subagentes delegados vía `spawn_agent`.
  /// `null` = heredar el modelo principal (proveedor/modelo de esta config).
  final SubagentModel? subagent;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AIConfig &&
        other.enabled == enabled &&
        other.provider == provider &&
        other.model == model &&
        other.temperature == temperature &&
        other.thinkingLevel == thinkingLevel &&
        other.systemPrompt == systemPrompt &&
        other.contextMessages == contextMessages &&
        other.responseDelaySeconds == responseDelaySeconds &&
        other.followUpEnabled == followUpEnabled &&
        other.followUpDelayMinutes == followUpDelayMinutes &&
        other.followUpMaxAttempts == followUpMaxAttempts &&
        other.subagent == subagent &&
        _stringListEquals(other.silenceLabelIds, silenceLabelIds) &&
        _stringListEquals(other.disabledToolGroups, disabledToolGroups);
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    provider,
    model,
    temperature,
    thinkingLevel,
    systemPrompt,
    contextMessages,
    responseDelaySeconds,
    Object.hashAll(silenceLabelIds),
    followUpEnabled,
    followUpDelayMinutes,
    followUpMaxAttempts,
    Object.hashAll(disabledToolGroups),
    subagent,
  );

  /// Copia con campos reemplazados — base de las ediciones por-campo del
  /// Motor IA (cada control muta UN campo y conserva el resto).
  ///
  /// `subagent` es nullable con semántica de tres estados: omitirlo conserva
  /// el valor previo; pasar `null` lo LIMPIA (vuelve a heredar); pasar un
  /// [SubagentModel] lo fija. Un `?? this.subagent` no distingue "limpiar"
  /// de "no tocar", así que se usa un centinela (`_keepSubagent`).
  AIConfig copyWith({
    bool? enabled,
    AIProvider? provider,
    String? model,
    double? temperature,
    ThinkingLevel? thinkingLevel,
    String? systemPrompt,
    int? contextMessages,
    int? responseDelaySeconds,
    List<String>? silenceLabelIds,
    List<String>? disabledToolGroups,
    bool? followUpEnabled,
    int? followUpDelayMinutes,
    int? followUpMaxAttempts,
    Object? subagent = _keepSubagent,
  }) => AIConfig(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    temperature: temperature ?? this.temperature,
    thinkingLevel: thinkingLevel ?? this.thinkingLevel,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    contextMessages: contextMessages ?? this.contextMessages,
    responseDelaySeconds: responseDelaySeconds ?? this.responseDelaySeconds,
    silenceLabelIds: silenceLabelIds ?? this.silenceLabelIds,
    disabledToolGroups: disabledToolGroups ?? this.disabledToolGroups,
    followUpEnabled: followUpEnabled ?? this.followUpEnabled,
    followUpDelayMinutes: followUpDelayMinutes ?? this.followUpDelayMinutes,
    followUpMaxAttempts: followUpMaxAttempts ?? this.followUpMaxAttempts,
    subagent: identical(subagent, _keepSubagent)
        ? this.subagent
        : subagent as SubagentModel?,
  );
}

/// Centinela del `copyWith` de [AIConfig] para el campo `subagent`: permite
/// distinguir "no tocar" (default) de "limpiar" (`null` explícito).
const Object _keepSubagent = Object();

/// Igualdad posicional de dos listas de strings (las etiquetas de silencio):
/// el dominio se mantiene puro (sin `package:flutter/foundation`), igual que
/// las comparaciones manuales de listas del resto de la capa.
bool _stringListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
