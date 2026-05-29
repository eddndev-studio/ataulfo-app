/// Tipo de una variable de plantilla (S03). Set v1 espejo del backend
/// (`ataulfo-go/internal/domain/template/variable_def.go`): text + label
/// + 4 multimedia. El interpolador del engine trata el valor como string
/// en runtime; el type es metadata semántica para el editor.
///
/// Política de wire: tokens lower-case canonical (el backend normaliza
/// al guardar). Cualquier token con casing distinto o fuera del set es
/// drift de contrato y rompe fail-loud — no se degrada a un "unknown"
/// cosmético, que escondería el bug del backend o de una versión del
/// cliente desactualizada.
enum VarType {
  text,
  label,
  image,
  video,
  audio,
  document;

  static VarType fromWire(String raw) => switch (raw) {
    'text' => VarType.text,
    'label' => VarType.label,
    'image' => VarType.image,
    'video' => VarType.video,
    'audio' => VarType.audio,
    'document' => VarType.document,
    _ => throw ArgumentError.value(raw, 'VarType.fromWire'),
  };

  /// Serializa al token canónico del wire. Switch exhaustivo: añadir un
  /// valor al enum sin extender este switch falla en compile-time.
  String toWire() => switch (this) {
    VarType.text => 'text',
    VarType.label => 'label',
    VarType.image => 'image',
    VarType.video => 'video',
    VarType.audio => 'audio',
    VarType.document => 'document',
  };
}

/// Definición de una variable de plantilla. Value object: dos instancias
/// con misma data son iguales. El nombre vive en el campo `name` aquí (el
/// backend lo guarda como llave del map y lo expone en el response — el
/// adaptador HTTP lo añade al DTO; ver `varDefResp` en ataulfo-go).
class VariableDef {
  const VariableDef({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultValue,
    required this.description,
  });

  final String id;
  final String name;
  final VarType type;
  final String defaultValue;
  final String description;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VariableDef &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.defaultValue == defaultValue &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, name, type, defaultValue, description);
}
