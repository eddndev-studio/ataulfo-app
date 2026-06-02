/// Lectura puntual de los `variable_values` de un Bot para el editor
/// (`GET /bots/:id/variables`, ADMIN+). Reúne los tres datos que el editor
/// necesita juntos y consistentes entre sí:
///
/// - `version`: el CAS del `PUT` subsiguiente. Viene de la MISMA lectura que
///   los valores, así el guardado no puede quedar a horcajadas de una edición
///   concurrente (la version y los valores mostrados son coherentes).
/// - `templateId`: para resolver las definiciones del catálogo (`listVarDefs`).
/// - `values`: los overrides ya guardados, para PRECARGAR el form. Mapa vacío
///   = el bot no tiene overrides (no es un error): cada campo arranca en el
///   default de la plantilla.
class BotVariablesSnapshot {
  const BotVariablesSnapshot({
    required this.version,
    required this.templateId,
    required this.values,
  });

  final int version;
  final String templateId;
  final Map<String, String> values;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BotVariablesSnapshot ||
        other.version != version ||
        other.templateId != templateId ||
        other.values.length != values.length) {
      return false;
    }
    for (final e in values.entries) {
      if (other.values[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // XOR sobre las entradas: independiente del orden de iteración del mapa,
    // así objetos iguales conservan hashCode igual.
    var entriesHash = 0;
    for (final e in values.entries) {
      entriesHash ^= Object.hash(e.key, e.value);
    }
    return Object.hash(version, templateId, entriesHash);
  }
}
