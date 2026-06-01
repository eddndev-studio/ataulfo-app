/// Mapeo explícito etiqueta-WhatsApp ↔ Label interno (S21, Dirección 2).
///
/// Value object. Une una etiqueta WhatsApp (`waLabelId`, color-índice) con un
/// Label interno (`labelId`, color-hex): son entidades separadas. El mapeo es
/// lo que convierte "etiqueté el chat en WhatsApp" en una automatización —
/// permite que la asociación dispare un trigger LABEL de un flujo.
///
/// Una etiqueta WA mapea a ≤1 Label interno por bot (set = upsert/re-map). El
/// mapeo NO empuja nada a WhatsApp: es metadata interna.
class WaLabelMapping {
  const WaLabelMapping({required this.waLabelId, required this.labelId});

  final String waLabelId;
  final String labelId;

  @override
  bool operator ==(Object other) =>
      other is WaLabelMapping &&
      other.waLabelId == waLabelId &&
      other.labelId == labelId;

  @override
  int get hashCode => Object.hash(waLabelId, labelId);
}
