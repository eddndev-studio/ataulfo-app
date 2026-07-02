/// Una escritura encolada en el outbox, proyectada para la UI del hilo (la
/// burbuja "enviando / fallido"). Deriva de una fila del outbox: `clientToken`
/// la identifica (y es su idempotency-key), `isFailed` distingue un fallo
/// TERMINAL (con `errorKind`, muestra reintentar/descartar) de uno en curso o
/// reintentable (que se sigue intentando y se pinta como "enviando").
class OutboxEntry {
  const OutboxEntry({
    required this.clientToken,
    required this.type,
    required this.content,
    required this.mediaRef,
    required this.isFailed,
    required this.errorKind,
    required this.createdAtMs,
    this.quotedId,
  });

  final String clientToken;
  final String type;
  final String content;
  final String? mediaRef;

  /// `externalId` del mensaje citado si la escritura es una respuesta; `null`
  /// en un envío normal.
  final String? quotedId;

  /// `true` sólo si la fila quedó en estado terminal `failed`.
  final bool isFailed;
  final String? errorKind;

  /// Epoch ms de encolado: orden FIFO de la burbuja y ancla para deduplicar el
  /// eco SSE (suprimir la burbuja cuando el mensaje real ya aterrizó).
  final int createdAtMs;

  @override
  bool operator ==(Object other) =>
      other is OutboxEntry &&
      other.clientToken == clientToken &&
      other.type == type &&
      other.content == content &&
      other.mediaRef == mediaRef &&
      other.quotedId == quotedId &&
      other.isFailed == isFailed &&
      other.errorKind == errorKind &&
      other.createdAtMs == createdAtMs;

  @override
  int get hashCode => Object.hash(
    clientToken,
    type,
    content,
    mediaRef,
    quotedId,
    isFailed,
    errorKind,
    createdAtMs,
  );
}
