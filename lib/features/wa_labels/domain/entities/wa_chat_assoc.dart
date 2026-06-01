/// Asociación etiqueta-WhatsApp ↔ chat espejada del bot (S21).
///
/// Value object. `labeled` es explícito: `false` es la señal de desasociación
/// (la etiqueta fue quitada del chat) y debe distinguirse de la asociación
/// activa — el espejo conserva la fila con `labeled:false`, no la borra.
class WaChatAssoc {
  const WaChatAssoc({
    required this.chatLid,
    required this.waLabelId,
    required this.labeled,
  });

  final String chatLid;
  final String waLabelId;
  final bool labeled;

  @override
  bool operator ==(Object other) =>
      other is WaChatAssoc &&
      other.chatLid == chatLid &&
      other.waLabelId == waLabelId &&
      other.labeled == labeled;

  @override
  int get hashCode => Object.hash(chatLid, waLabelId, labeled);
}
