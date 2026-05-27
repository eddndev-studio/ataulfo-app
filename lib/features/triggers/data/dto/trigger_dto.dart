/// DTO del listado `GET /templates/{templateId}/triggers` (ver
/// `triggerResp` en `agentic-go/internal/adapters/httpflows/trigger_dto.go`).
///
/// Campos enum del wire (`type`, `matchType`, `labelAction`, `scope`) se
/// preservan como `String` aquí; el mapeo a los enums del dominio ocurre
/// en `TriggersMapper`, donde un drift (valor nuevo en el backend que el
/// cliente no conoce) propaga `ArgumentError` fail-loud sin envolver.
///
/// El json key `type` del wire se renombra al campo `type` en el DTO (1:1)
/// pero el mapper lo traduce a `triggerType` en la entidad para
/// legibilidad en call sites del dominio.
///
/// Campos opcionales del wire (`matchType`/`keyword`/`labelId`/
/// `labelAction`, todos `omitempty` en el backend) se materializan como
/// `null`/`''` aquí — el shape por modo (TEXT vs LABEL) lo enforza el
/// backend en validate(); el cliente sólo presenta.
class TriggerResp {
  const TriggerResp({
    required this.id,
    required this.templateId,
    required this.flowId,
    required this.type,
    required this.matchType,
    required this.keyword,
    required this.labelId,
    required this.labelAction,
    required this.scope,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory TriggerResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final templateId = json['templateId'];
    final flowId = json['flowId'];
    final type = json['type'];
    final scope = json['scope'];
    final isActive = json['isActive'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        templateId is! String ||
        flowId is! String ||
        type is! String ||
        scope is! String ||
        isActive is! bool ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('triggerResp con campos requeridos faltantes o de tipo incorrecto');
    }

    final rawMatchType = json['matchType'];
    final rawKeyword = json['keyword'];
    final rawLabelId = json['labelId'];
    final rawLabelAction = json['labelAction'];

    return TriggerResp(
      id: id,
      templateId: templateId,
      flowId: flowId,
      type: type,
      matchType: rawMatchType is String ? rawMatchType : null,
      keyword: rawKeyword is String ? rawKeyword : '',
      labelId: rawLabelId is String ? rawLabelId : '',
      labelAction: rawLabelAction is String ? rawLabelAction : null,
      scope: scope,
      isActive: isActive,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  final String id;
  final String templateId;
  final String flowId;
  final String type;
  final String? matchType;
  final String keyword;
  final String labelId;
  final String? labelAction;
  final String scope;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Atajo para tests: instancia el DTO sin timestamps en el const
  /// constructor y los anexa después.
  TriggerResp withTimestamps({required DateTime createdAt, required DateTime updatedAt}) =>
      TriggerResp(
        id: id,
        templateId: templateId,
        flowId: flowId,
        type: type,
        matchType: matchType,
        keyword: keyword,
        labelId: labelId,
        labelAction: labelAction,
        scope: scope,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Wrapper del listado `{items: [...]}` que el backend devuelve. El
/// shape externo coincide con el resto de los list endpoints del repo
/// (flows, steps, variable-definitions).
class ListTriggersResp {
  const ListTriggersResp({required this.items});

  factory ListTriggersResp.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('listTriggersResp sin items array');
    }
    return ListTriggersResp(
      items: items
          .cast<Map<String, dynamic>>()
          .map(TriggerResp.fromJson)
          .toList(growable: false),
    );
  }

  final List<TriggerResp> items;
}
