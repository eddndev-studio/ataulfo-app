/// Flow — cabeza de una automatización (S11). Posee Steps[] + Triggers[]
/// como sub-recursos en sus propios paquetes; aquí sólo vive la cabecera
/// que la UI necesita para listar y abrir el editor.
///
/// `version` se conserva en la entity (aunque la UI de listado no la
/// muestra) para que el editor de gates (CAS optimista) la consuma sin
/// reabrir la cabecera al guardar.
///
/// `cooldownMs` / `usageLimit` / `excludesFlows` / `createdAt` /
/// `updatedAt` viven en el wire pero quedan fuera de la entity hasta que
/// el editor de gates los necesite — leerlos hoy sin uso introduce
/// drift entre el mapeo y el dominio.
class Flow {
  const Flow({
    required this.id,
    required this.templateId,
    required this.name,
    required this.isActive,
    required this.version,
  });

  final String id;
  final String templateId;
  final String name;
  final bool isActive;
  final int version;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Flow &&
        other.id == id &&
        other.templateId == templateId &&
        other.name == name &&
        other.isActive == isActive &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, templateId, name, isActive, version);
}
