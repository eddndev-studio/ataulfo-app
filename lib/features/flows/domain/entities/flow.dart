/// Flow — cabeza de una automatización (S11). Posee Steps[] + Triggers[]
/// como sub-recursos en sus propios paquetes; aquí sólo vive la cabecera
/// que la UI necesita para listar y abrir el editor.
///
/// `version` se conserva para que el editor de configuración (CAS
/// optimista) la consuma sin reabrir la cabecera al guardar.
///
/// `cooldownMs` / `usageLimit` / `excludesFlows` son los gates de
/// comportamiento: cooldown en milisegundos entre ejecuciones del flujo,
/// límite de usos totales (0 ⇒ sin límite, semántica del dominio), y
/// lista de ids de OTROS flujos cuya ejecución concurrente bloquea a
/// este. Viven en la entity porque el editor los lee y los reescribe
/// como un solo documento (PUT replace-completo).
///
/// `createdAt` / `updatedAt` viven en el wire pero quedan fuera de la
/// entity — ninguna superficie de UI los consume hoy.
class Flow {
  const Flow({
    required this.id,
    required this.templateId,
    required this.name,
    required this.isActive,
    required this.version,
    required this.cooldownMs,
    required this.usageLimit,
    required this.excludesFlows,
    this.aiInvocable = false,
  });

  final String id;
  final String templateId;
  final String name;
  final bool isActive;

  /// Allowlist del agente IA (S11 RF#17): sólo los flows marcados pueden ser
  /// listados/ejecutados por el agente conversacional. Default `false` —
  /// que un LLM dispare un flujo es opt-in explícito del operador.
  final bool aiInvocable;

  final int version;
  final int cooldownMs;
  final int usageLimit;
  final List<String> excludesFlows;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Flow) return false;
    if (other.id != id ||
        other.templateId != templateId ||
        other.name != name ||
        other.isActive != isActive ||
        other.aiInvocable != aiInvocable ||
        other.version != version ||
        other.cooldownMs != cooldownMs ||
        other.usageLimit != usageLimit) {
      return false;
    }
    if (other.excludesFlows.length != excludesFlows.length) return false;
    for (var i = 0; i < excludesFlows.length; i++) {
      if (other.excludesFlows[i] != excludesFlows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    name,
    isActive,
    aiInvocable,
    version,
    cooldownMs,
    usageLimit,
    Object.hashAll(excludesFlows),
  );
}
