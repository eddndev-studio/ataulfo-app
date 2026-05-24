/// Canal de mensajería al que el Bot está ligado (S04 I-B3: inmutable tras
/// la primera conexión — el wire NUNCA admite cambio vía PUT; un cambio de
/// canal exige Bot nuevo).
///
/// Política frente a un valor desconocido en el wire (fail-loud): si el
/// backend añade un canal nuevo (p. ej. `WABA_CLOUD`) el cliente DEBE romper
/// al parsear; degradar a un "unknown" cosmético escondería drift de
/// contrato y la UI mostraría bots imposibles de operar.
enum BotChannel {
  waUnofficial,
  waba;

  static BotChannel fromWire(String raw) => switch (raw) {
    'WA_UNOFFICIAL' => BotChannel.waUnofficial,
    'WABA' => BotChannel.waba,
    _ => throw ArgumentError.value(raw, 'BotChannel.fromWire'),
  };
}

/// Entidad de dominio del Bot (S04). Espeja el `botResp` del backend
/// (`agentic-go/internal/adapters/httpbots/dto.go`) sin nombres del wire:
/// los mappers traducen DTO ⇄ entidad.
class Bot {
  const Bot({
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

  final String id;
  final String orgId;
  final String templateId;
  final String name;
  final BotChannel channel;

  /// Label libre opcional v1 (en WABA aterrizará como número verificado).
  final String? identifier;
  final int version;
  final bool paused;
  final bool aiDisabled;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bot &&
        other.id == id &&
        other.orgId == orgId &&
        other.templateId == templateId &&
        other.name == name &&
        other.channel == channel &&
        other.identifier == identifier &&
        other.version == version &&
        other.paused == paused &&
        other.aiDisabled == aiDisabled;
  }

  @override
  int get hashCode => Object.hash(
    id,
    orgId,
    templateId,
    name,
    channel,
    identifier,
    version,
    paused,
    aiDisabled,
  );
}
