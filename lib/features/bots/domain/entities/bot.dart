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

  /// Serializa al literal exacto del contrato. Inversa de `fromWire`: la
  /// presentación nunca toca strings del wire.
  String toWire() => switch (this) {
    BotChannel.waUnofficial => 'WA_UNOFFICIAL',
    BotChannel.waba => 'WABA',
  };
}

/// Entidad de dominio del Bot (S04). Espeja el `botResp` del backend
/// (`ataulfo-go/internal/adapters/httpbots/dto.go`) sin nombres del wire:
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
    this.disabledToolGroups = const <String>[],
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

  /// Override por-Bot de la deny-list de grupos de capacidad del agente IA
  /// (ids de `ToolGroup`): grupos que ESTE bot apaga ADEMÁS de los que apaga su
  /// plantilla. El permiso efectivo es la unión plantilla ∪ bot; el bot sólo
  /// restringe. Vacío = no añade restricciones. Ids crudos (tolerante a un grupo
  /// futuro), igual que el override del backend.
  final List<String> disabledToolGroups;

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
        other.aiDisabled == aiDisabled &&
        _listEquals(other.disabledToolGroups, disabledToolGroups);
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
    Object.hashAll(disabledToolGroups),
  );
}

/// Igualdad posicional de dos listas de strings (sin depender de `foundation`),
/// para comparar el override de grupos del Bot.
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
