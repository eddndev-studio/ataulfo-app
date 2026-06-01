/// Asociación etiqueta-WhatsApp ↔ mensaje espejada del bot (S21).
///
/// Value object. El `messageId` es el wamid del mensaje etiquetado. `labeled`
/// es explícito (`false` = desasociación; el espejo conserva la fila).
class WaMsgAssoc {
  const WaMsgAssoc({
    required this.chatLid,
    required this.messageId,
    required this.waLabelId,
    required this.labeled,
  });

  final String chatLid;
  final String messageId;
  final String waLabelId;
  final bool labeled;

  @override
  bool operator ==(Object other) =>
      other is WaMsgAssoc &&
      other.chatLid == chatLid &&
      other.messageId == messageId &&
      other.waLabelId == waLabelId &&
      other.labeled == labeled;

  @override
  int get hashCode => Object.hash(chatLid, messageId, waLabelId, labeled);
}
