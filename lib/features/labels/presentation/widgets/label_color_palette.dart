/// Paleta curada de colores para Labels internos. El backend acepta cualquier
/// hex `#RRGGBB`, pero ofrecer un set fijo y armónico evita que el operador
/// teclee hex a mano y mantiene el catálogo visualmente consistente. Si una
/// etiqueta ya trae un color fuera de esta paleta (creada por API), el selector
/// lo conserva como swatch aparte.
class LabelColorPalette {
  const LabelColorPalette._();

  /// Colores en minúscula (el backend normaliza a lowercase de todos modos).
  static const List<String> hexColors = <String>[
    '#ef4444', // rojo
    '#f97316', // naranja
    '#f59e0b', // ámbar
    '#eab308', // amarillo
    '#84cc16', // lima
    '#22c55e', // verde
    '#10b981', // esmeralda
    '#14b8a6', // turquesa
    '#06b6d4', // cian
    '#3b82f6', // azul
    '#6366f1', // índigo
    '#7c3aed', // violeta
    '#a855f7', // púrpura
    '#ec4899', // rosa
    '#64748b', // pizarra
  ];
}
