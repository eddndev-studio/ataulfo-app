/// Tipo de un Trigger (S11). 2 valores espejo del backend
/// (`agentic-go/internal/domain/flow/trigger.go`):
/// - TEXT: matchea keyword (con `matchType`) sobre el body de mensajes.
/// - LABEL: dispara sobre cambio interno de SessionLabel (I-L1, evento
///   interno de la plataforma — nunca eventos de WhatsApp).
///
/// Wire UPPERCASE canonical. El backend rechaza casing distinto en
/// validate(); el cliente espeja el wire fail-loud (no normaliza). Drift
/// en boot, no failure reintentable.
enum TriggerType {
  text,
  label;

  static TriggerType fromWire(String raw) => switch (raw) {
    'TEXT' => TriggerType.text,
    'LABEL' => TriggerType.label,
    _ => throw ArgumentError.value(raw, 'TriggerType.fromWire'),
  };

  String toWire() => switch (this) {
    TriggerType.text => 'TEXT',
    TriggerType.label => 'LABEL',
  };
}

/// Modo de comparación de la keyword en triggers TEXT. REGEX implica que
/// el backend ya validó la sintaxis al crear; el cliente sólo presenta.
enum MatchType {
  exact,
  contains,
  regex;

  static MatchType fromWire(String raw) => switch (raw) {
    'EXACT' => MatchType.exact,
    'CONTAINS' => MatchType.contains,
    'REGEX' => MatchType.regex,
    _ => throw ArgumentError.value(raw, 'MatchType.fromWire'),
  };

  String toWire() => switch (this) {
    MatchType.exact => 'EXACT',
    MatchType.contains => 'CONTAINS',
    MatchType.regex => 'REGEX',
  };
}

/// Discrimina si el trigger LABEL dispara al agregar o al quitar la
/// label asociada a la sesión.
enum LabelAction {
  add,
  remove;

  static LabelAction fromWire(String raw) => switch (raw) {
    'ADD' => LabelAction.add,
    'REMOVE' => LabelAction.remove,
    _ => throw ArgumentError.value(raw, 'LabelAction.fromWire'),
  };

  String toWire() => switch (this) {
    LabelAction.add => 'ADD',
    LabelAction.remove => 'REMOVE',
  };
}

/// Acota qué tráfico evalúa un trigger TEXT. BOTH es el default del
/// backend cuando no se especifica. Renombrado en el cliente desde
/// `Scope` (backend) para evitar un nombre genérico que colisiona con
/// otros conceptos de scope en el dominio Dart.
enum TriggerScope {
  incoming,
  outgoing,
  both;

  static TriggerScope fromWire(String raw) => switch (raw) {
    'INCOMING' => TriggerScope.incoming,
    'OUTGOING' => TriggerScope.outgoing,
    'BOTH' => TriggerScope.both,
    _ => throw ArgumentError.value(raw, 'TriggerScope.fromWire'),
  };

  String toWire() => switch (this) {
    TriggerScope.incoming => 'INCOMING',
    TriggerScope.outgoing => 'OUTGOING',
    TriggerScope.both => 'BOTH',
  };
}

/// Trigger — disparador de un Flow desde un evento de mensaje (TEXT) o
/// cambio de label de sesión (LABEL).
///
/// Value object: dos instancias con misma data son iguales.
///
/// Campos condicionales según `triggerType`:
/// - TEXT  ⇒ `matchType` + `keyword` se usan; `labelId`+`labelAction`
///   permanecen vacíos/null (espejo del backend que limpia el campo
///   opuesto al construir el trigger).
/// - LABEL ⇒ `labelId` + `labelAction` se usan; `matchType`+`keyword`
///   permanecen null/vacío.
///
/// El campo `triggerType` se renombra desde el wire `type` (json key)
/// para legibilidad en el call site (evita colisión visual con
/// `Step.type` y deja claro que es el tipo del trigger).
class Trigger {
  const Trigger({
    required this.id,
    required this.templateId,
    required this.flowId,
    required this.triggerType,
    required this.matchType,
    required this.keyword,
    required this.labelId,
    required this.labelAction,
    required this.scope,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String flowId;
  final TriggerType triggerType;
  final MatchType? matchType;
  final String keyword;
  final String labelId;
  final LabelAction? labelAction;
  final TriggerScope scope;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Trigger copyWith({
    String? id,
    String? templateId,
    String? flowId,
    TriggerType? triggerType,
    MatchType? matchType,
    String? keyword,
    String? labelId,
    LabelAction? labelAction,
    TriggerScope? scope,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Trigger(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    flowId: flowId ?? this.flowId,
    triggerType: triggerType ?? this.triggerType,
    matchType: matchType ?? this.matchType,
    keyword: keyword ?? this.keyword,
    labelId: labelId ?? this.labelId,
    labelAction: labelAction ?? this.labelAction,
    scope: scope ?? this.scope,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Trigger &&
        other.id == id &&
        other.templateId == templateId &&
        other.flowId == flowId &&
        other.triggerType == triggerType &&
        other.matchType == matchType &&
        other.keyword == keyword &&
        other.labelId == labelId &&
        other.labelAction == labelAction &&
        other.scope == scope &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    flowId,
    triggerType,
    matchType,
    keyword,
    labelId,
    labelAction,
    scope,
    isActive,
    createdAt,
    updatedAt,
  );
}
