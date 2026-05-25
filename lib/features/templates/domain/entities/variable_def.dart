/// Tipo de una variable de plantilla (S03). v1 sólo `text` — espejo del
/// set mínimo del backend (`internal/domain/template/variable_def.go`).
/// Cualquier extensión futura (number/date) aterriza primero aquí como
/// entrada explícita; un valor desconocido en el wire es bug de contrato
/// y debe romper en boot, no degradar.
enum VarType {
  text;

  static VarType fromWire(String raw) => switch (raw) {
    'text' => VarType.text,
    _ => throw ArgumentError.value(raw, 'VarType.fromWire'),
  };
}

/// Definición de una variable de plantilla. Value object: dos instancias
/// con misma data son iguales. El nombre vive en el campo `name` aquí (el
/// backend lo guarda como llave del map y lo expone en el response — el
/// adaptador HTTP lo añade al DTO; ver `varDefResp` en agentic-go).
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
  int get hashCode =>
      Object.hash(id, name, type, defaultValue, description);
}
