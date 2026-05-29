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
  });

  final bool enabled;
  final AIProvider provider;
  final String model;
  final double temperature;
  final ThinkingLevel thinkingLevel;
  final String systemPrompt;
  final int contextMessages;

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
        other.contextMessages == contextMessages;
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
  );
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
  });

  final String id;
  final String orgId;
  final String name;
  final int version;
  final AIConfig ai;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.id == id &&
        other.orgId == orgId &&
        other.name == name &&
        other.version == version &&
        other.ai == ai;
  }

  @override
  int get hashCode => Object.hash(id, orgId, name, version, ai);
}
