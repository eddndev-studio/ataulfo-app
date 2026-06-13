/// Proveedor LLM del motor IA (S12). Set cerrado: si el backend agrega uno
/// nuevo (p. ej. "ANTHROPIC") el cliente DEBE romper al parsear; degradar a
/// un "unknown" cosmético escondería drift de contrato y la UI mostraría
/// configuraciones imposibles de aplicar.
enum AIProvider {
  openai,
  gemini,
  minimax,
  deepseek;

  static AIProvider fromWire(String raw) => switch (raw) {
    'OPENAI' => AIProvider.openai,
    'GEMINI' => AIProvider.gemini,
    'MINIMAX' => AIProvider.minimax,
    'DEEPSEEK' => AIProvider.deepseek,
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
  };
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
        _stringListEquals(other.silenceLabelIds, silenceLabelIds);
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
  );

  /// Copia con campos reemplazados — base de las ediciones por-campo del
  /// Motor IA (cada control muta UN campo y conserva el resto).
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
  );
}

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

/// Conteo de agregados hijos de una Template, para las tarjetas del listado
/// ("3 bots · 12 flujos · 4 variables"). Value object. Solo `GET /templates`
/// lo entrega; las respuestas de entidad única (detalle, create, update,
/// duplicate) NO lo traen — por eso [Template.counts] es nullable.
class TemplateCounts {
  const TemplateCounts({
    required this.bots,
    required this.flows,
    required this.variables,
  });

  final int bots;
  final int flows;
  final int variables;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplateCounts &&
        other.bots == bots &&
        other.flows == flows &&
        other.variables == variables;
  }

  @override
  int get hashCode => Object.hash(bots, flows, variables);
}

/// Entidad de dominio Template (S03). Espeja `templateResp` del backend
/// (`ataulfo-go/internal/adapters/httptemplates/dto.go`) sin nombres del
/// wire: los mappers traducen DTO ⇄ entidad. La Template es la entidad
/// principal: posee el comportamiento que heredan sus Bots.
class Template {
  const Template({
    required this.id,
    required this.orgId,
    required this.name,
    required this.version,
    required this.ai,
    this.counts,
  });

  final String id;
  final String orgId;
  final String name;
  final int version;
  final AIConfig ai;

  /// Conteos de hijos para el listado; null fuera de `GET /templates`.
  final TemplateCounts? counts;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.id == id &&
        other.orgId == orgId &&
        other.name == name &&
        other.version == version &&
        other.ai == ai &&
        other.counts == counts;
  }

  @override
  int get hashCode => Object.hash(id, orgId, name, version, ai, counts);
}
