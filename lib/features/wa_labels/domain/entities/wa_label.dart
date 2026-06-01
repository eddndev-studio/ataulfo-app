/// Etiqueta WhatsApp Business espejada del bot (S21, canal no-oficial).
///
/// Value object: dos instancias con la misma data son iguales.
///
/// `color` es el **índice de paleta de WhatsApp** (entero crudo, sin hex; 0 es
/// un índice válido). Distinto del `color` hex de un Label interno (S10): no se
/// confunden ni se convierten — la UI resuelve el índice a un swatch.
///
/// `deleted` es un **tombstone explícito**: el espejo puede devolver etiquetas
/// borradas (el catálogo es fiel al cliente de WhatsApp); la UI no las pinta
/// como activas.
class WaLabel {
  const WaLabel({
    required this.waLabelId,
    required this.name,
    required this.color,
    required this.deleted,
  });

  final String waLabelId;
  final String name;
  final int color;
  final bool deleted;

  WaLabel copyWith({
    String? waLabelId,
    String? name,
    int? color,
    bool? deleted,
  }) => WaLabel(
    waLabelId: waLabelId ?? this.waLabelId,
    name: name ?? this.name,
    color: color ?? this.color,
    deleted: deleted ?? this.deleted,
  );

  @override
  bool operator ==(Object other) =>
      other is WaLabel &&
      other.waLabelId == waLabelId &&
      other.name == name &&
      other.color == color &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(waLabelId, name, color, deleted);
}
