/// Label interno de la organización (S10). Es la etiqueta que el operador
/// gestiona en la plataforma (org-scoped), distinta de la etiqueta WhatsApp
/// (per-bot): su `color` es un **string hex** (`#RRGGBB`), no un índice de
/// paleta.
///
/// Value object. En esta capa solo se lee (poblar el selector del mapeo
/// WA↔interno); el CRUD completo de Labels vive en su propia sección.
class Label {
  const Label({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
  });

  final String id;
  final String name;

  /// Color hex `#RRGGBB` (no índice de paleta — eso es la etiqueta WhatsApp).
  final String color;
  final String description;

  @override
  bool operator ==(Object other) =>
      other is Label &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, name, color, description);
}
