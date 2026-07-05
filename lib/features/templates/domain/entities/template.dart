import '../../../../core/ai/ai_config.dart';

export '../../../../core/ai/ai_config.dart';

/// Conteo de agregados hijos de una Template, para las tarjetas del listado
/// ("3 bots · 12 flujos · 4 variables"). Value object. Solo `GET /templates`
/// lo entrega; las respuestas de entidad única (detalle, create, update,
/// duplicate) NO lo traen — por eso [Template.counts] es nullable.
class TemplateCounts {
  const TemplateCounts({
    required this.bots,
    required this.flows,
    required this.variables,
  });

  final int bots;
  final int flows;
  final int variables;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplateCounts &&
        other.bots == bots &&
        other.flows == flows &&
        other.variables == variables;
  }

  @override
  int get hashCode => Object.hash(bots, flows, variables);
}

/// Entidad de dominio Template (S03). Espeja `templateResp` del backend
/// (`ataulfo-go/internal/adapters/httptemplates/dto.go`) sin nombres del
/// wire: los mappers traducen DTO ⇄ entidad. La Template es la entidad
/// principal: posee el comportamiento que heredan sus Bots.
class Template {
  const Template({
    required this.id,
    required this.orgId,
    required this.name,
    required this.version,
    required this.ai,
    this.counts,
  });

  final String id;
  final String orgId;
  final String name;
  final int version;
  final AIConfig ai;

  /// Conteos de hijos para el listado; null fuera de `GET /templates`.
  final TemplateCounts? counts;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.id == id &&
        other.orgId == orgId &&
        other.name == name &&
        other.version == version &&
        other.ai == ai &&
        other.counts == counts;
  }

  @override
  int get hashCode => Object.hash(id, orgId, name, version, ai, counts);
}
