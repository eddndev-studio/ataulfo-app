/// Definición de una variable de plantilla. Value object: dos instancias
/// con misma data son iguales. El nombre vive en el campo `name` aquí (el
/// backend lo guarda como llave del map y lo expone en el response — el
/// adaptador HTTP lo añade al DTO; ver `varDefResp` en ataulfo-go).
///
/// Las variables son solo-texto: el interpolador del engine trata el valor
/// como string en runtime y el editor no expone un concepto de tipo.
class VariableDef {
  const VariableDef({
    required this.id,
    required this.name,
    required this.defaultValue,
    required this.description,
  });

  final String id;
  final String name;
  final String defaultValue;
  final String description;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VariableDef &&
        other.id == id &&
        other.name == name &&
        other.defaultValue == defaultValue &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(id, name, defaultValue, description);
}
