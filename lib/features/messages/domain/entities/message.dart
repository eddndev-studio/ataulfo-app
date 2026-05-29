/// Tipo de conversación a la que pertenece el mensaje (DM o grupo), paralelo a
/// `ConversationKind`. Se recibe explícito del wire. Fail-loud ante un valor
/// desconocido: `kind` SIEMPRE viene en el contrato (sin omitempty), así que un
/// valor nuevo es drift de contrato y el cliente debe romper, no degradar.
enum MessageKind {
  dm,
  group;

  static MessageKind fromWire(String raw) => switch (raw) {
    'DM' => MessageKind.dm,
    'GROUP' => MessageKind.group,
    _ => throw ArgumentError.value(raw, 'MessageKind.fromWire'),
  };
}

/// Sentido del mensaje. INBOUND = lo envió el contacto; OUTBOUND = lo envió el
/// bot/operador. Determina la alineación de la burbuja en el hilo. Siempre
/// presente en el wire ⇒ fail-loud ante valor desconocido.
enum MessageDirection {
  inbound,
  outbound;

  static MessageDirection fromWire(String raw) => switch (raw) {
    'INBOUND' => MessageDirection.inbound,
    'OUTBOUND' => MessageDirection.outbound,
    _ => throw ArgumentError.value(raw, 'MessageDirection.fromWire'),
  };
}

/// Estado de entrega de un OUTBOUND. Los INBOUND no llevan máquina de estados
/// (regla S09): el wire los emite con `status` omitempty (ausente o vacío).
///
/// `fromWire` distingue dos casos a propósito:
///   - `null`/`''` ⇒ `null` (sin estado de entrega; NO es error).
///   - un valor NO vacío desconocido ⇒ `ArgumentError` (fail-loud: drift).
enum MessageStatus {
  sent,
  delivered,
  read,
  failed;

  static MessageStatus? fromWire(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'SENT' => MessageStatus.sent,
      'DELIVERED' => MessageStatus.delivered,
      'READ' => MessageStatus.read,
      'FAILED' => MessageStatus.failed,
      _ => throw ArgumentError.value(raw, 'MessageStatus.fromWire'),
    };
  }
}

/// Un mensaje del historial de una conversación (S09 `GET
/// /sessions/:botId/:chatLid/messages`). Pertenece a la Session por `chatLid`;
/// `senderLid` es el autor (en DM == chatLid; en GROUP el participante).
///
/// Slice 1: identidad + contenido textual + estado de entrega. La media no se
/// descarga (`mediaRef` es una referencia opaca de storage); los tipos no-texto
/// se pintan como placeholder. `deliveredAt`/`readAt` aún no se exponen en el
/// wire — sólo el `status` agregado.
class Message {
  const Message({
    required this.externalId,
    required this.chatLid,
    required this.senderLid,
    required this.kind,
    required this.direction,
    required this.type,
    required this.content,
    required this.mediaRef,
    required this.quotedId,
    required this.timestampMs,
    required this.status,
  });

  final String externalId;
  final String chatLid;
  final String senderLid;
  final MessageKind kind;
  final MessageDirection direction;

  /// Tipo del mensaje (`text`, `image`, …). Slice 1 sólo renderiza `text`;
  /// el resto cae a placeholder.
  final String type;
  final String content;

  /// Referencia opaca a storage (media inbound/outbound). `null` si no aplica.
  final String? mediaRef;

  /// `externalId` del mensaje citado (reply), o `null`.
  final String? quotedId;

  /// Epoch en milisegundos. Clave de orden estable junto a `externalId`.
  final int timestampMs;

  /// Estado de entrega (OUTBOUND). `null` en INBOUND.
  final MessageStatus? status;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.externalId == externalId &&
        other.chatLid == chatLid &&
        other.senderLid == senderLid &&
        other.kind == kind &&
        other.direction == direction &&
        other.type == type &&
        other.content == content &&
        other.mediaRef == mediaRef &&
        other.quotedId == quotedId &&
        other.timestampMs == timestampMs &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
    externalId,
    chatLid,
    senderLid,
    kind,
    direction,
    type,
    content,
    mediaRef,
    quotedId,
    timestampMs,
    status,
  );
}
