import '../../../templates/domain/entities/template.dart';

/// Configuración de IA a nivel ORGANIZACIÓN (`GET/PUT /org/ai-config`,
/// ADMIN/OWNER). Dos partes:
///
///   - [hosts]: por modelo, el host que la org fijó (idModelo → host). Una
///     entrada ausente ⇒ ese modelo usa la cadena default del backend. Solo
///     los modelos con elección real (multi-host del catálogo) se fijan; los
///     de un solo host se pintan bloqueados y no entran al mapa.
///   - [defaults]: la [AIConfig] que heredan las plantillas NUEVAS de la org al
///     crearse (no afecta plantillas existentes ni la resolución en runtime).
///
/// La plantilla elige el MODELO; esta superficie elige el PROVEEDOR/HOST por
/// modelo y los defaults — nunca se cruza con la página de IA de la plantilla.
class OrgAiConfig {
  const OrgAiConfig({required this.hosts, required this.defaults});

  final Map<String, String> hosts;
  final AIConfig defaults;

  /// Host fijado para [modelId], o `null` si la org no fijó ninguno.
  String? hostFor(String modelId) => hosts[modelId];

  /// Fija (o reemplaza) el host de [modelId]. Es la edición por-modelo del
  /// selector; conserva el resto del mapa y los defaults.
  OrgAiConfig withHost(String modelId, String host) => OrgAiConfig(
    hosts: <String, String>{...hosts, modelId: host},
    defaults: defaults,
  );

  /// Quita el host fijado de [modelId] (vuelve a la cadena default). No-op si
  /// no estaba fijado.
  OrgAiConfig clearHost(String modelId) {
    if (!hosts.containsKey(modelId)) return this;
    final next = <String, String>{...hosts}..remove(modelId);
    return OrgAiConfig(hosts: next, defaults: defaults);
  }

  /// Reemplaza el bloque de defaults conservando los hosts.
  OrgAiConfig withDefaults(AIConfig next) =>
      OrgAiConfig(hosts: hosts, defaults: next);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OrgAiConfig) return false;
    if (other.defaults != defaults) return false;
    if (other.hosts.length != hosts.length) return false;
    for (final e in hosts.entries) {
      if (other.hosts[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // Orden-independiente para el mapa: XOR de los hashes por entrada.
    var h = 0;
    for (final e in hosts.entries) {
      h ^= Object.hash(e.key, e.value);
    }
    return Object.hash(h, defaults);
  }
}
