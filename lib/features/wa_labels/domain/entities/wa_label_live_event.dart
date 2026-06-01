/// Un evento del stream en vivo de etiquetas WhatsApp (S21, familia SSE
/// `label.wa.*`). Espeja `ThreadLiveEvent` (S15): es, o un cambio reflejado del
/// catálogo/asociaciones, o un aviso de reconexión tras un corte.
///
/// La distinción es de dominio: el consumidor parchea su estado con los cambios
/// y, ante una reconexión, reconcilia contra la verdad HTTP — el stream SSE no
/// reproduce el tramo del corte (solo emite deltas), así que reconectar exige
/// refrescar para no perder cambios.
sealed class WaLabelLiveEvent {
  const WaLabelLiveEvent();
}

/// Cambió el catálogo de una etiqueta (kinds `EDITED`/`REMOVED`). `removed:true`
/// es el tombstone (la etiqueta fue borrada en WhatsApp): el catálogo la marca
/// `deleted`. `removed:false` es alta/edición. `name` puede venir vacío en un
/// tombstone (el espejo no lo necesita para ocultarla).
class WaLabelCatalogChanged extends WaLabelLiveEvent {
  const WaLabelCatalogChanged({
    required this.waLabelId,
    required this.name,
    required this.color,
    required this.removed,
  });

  final String waLabelId;
  final String name;
  final int color;
  final bool removed;

  @override
  bool operator ==(Object other) =>
      other is WaLabelCatalogChanged &&
      other.waLabelId == waLabelId &&
      other.name == name &&
      other.color == color &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(waLabelId, name, color, removed);
}

/// Cambió una asociación etiqueta↔chat (kind `CHAT`). `labeled:false` es
/// desasociación. `color` viaja siempre (la etiqueta vive) para que la UI pueda
/// pintar el swatch sin reconsultar el catálogo.
class WaChatLabelChanged extends WaLabelLiveEvent {
  const WaChatLabelChanged({
    required this.waLabelId,
    required this.chatLid,
    required this.color,
    required this.labeled,
  });

  final String waLabelId;
  final String chatLid;
  final int color;
  final bool labeled;

  @override
  bool operator ==(Object other) =>
      other is WaChatLabelChanged &&
      other.waLabelId == waLabelId &&
      other.chatLid == chatLid &&
      other.color == color &&
      other.labeled == labeled;

  @override
  int get hashCode => Object.hash(waLabelId, chatLid, color, labeled);
}

/// Cambió una asociación etiqueta↔mensaje (kind `MESSAGE`). Incluye el
/// `messageId` (wamid) del mensaje afectado.
class WaMessageLabelChanged extends WaLabelLiveEvent {
  const WaMessageLabelChanged({
    required this.waLabelId,
    required this.chatLid,
    required this.messageId,
    required this.color,
    required this.labeled,
  });

  final String waLabelId;
  final String chatLid;
  final String messageId;
  final int color;
  final bool labeled;

  @override
  bool operator ==(Object other) =>
      other is WaMessageLabelChanged &&
      other.waLabelId == waLabelId &&
      other.chatLid == chatLid &&
      other.messageId == messageId &&
      other.color == color &&
      other.labeled == labeled;

  @override
  int get hashCode =>
      Object.hash(waLabelId, chatLid, messageId, color, labeled);
}

/// La conexión SSE se reconectó tras un corte. No trae datos: es la señal para
/// que el consumidor reconcilie el catálogo/asociaciones contra el GET por HTTP.
class WaLabelReconnected extends WaLabelLiveEvent {
  const WaLabelReconnected();

  @override
  bool operator ==(Object other) => other is WaLabelReconnected;

  @override
  int get hashCode => (WaLabelReconnected).hashCode;
}
