import 'dart:convert';

/// Acción de un paso LABEL: aplicar (ADD) o quitar (REMOVE) la etiqueta sobre
/// el chat de la Execution. Tokens de wire **UPPERCASE** espejo del backend
/// (`LabelAction` en `domain/flow/trigger.go`).
enum LabelStepAction {
  add,
  remove;

  static LabelStepAction fromWire(String raw) => switch (raw) {
    'ADD' => LabelStepAction.add,
    'REMOVE' => LabelStepAction.remove,
    _ => throw FormatException('label metadata: action inválida: "$raw"'),
  };

  String toWire() => switch (this) {
    LabelStepAction.add => 'ADD',
    LabelStepAction.remove => 'REMOVE',
  };
}

/// Shape de `Step.metadata` para el nodo LABEL (S11): aplica (ADD) o quita
/// (REMOVE) la org-label `labelId` sobre el chat de la Execution. El cliente
/// edita el shape literal; esta entity es su representación tipada del JSON
/// opaco que viaja en el wire.
///
/// Wire keys **snake_case** (`label_id`, `action`) — espejo del backend
/// (`step_metadata.go`); cualquier cambio allá se replica acá.
class LabelStepMetadata {
  const LabelStepMetadata({required this.labelId, required this.action});

  final String labelId;
  final LabelStepAction action;

  /// Decodifica + valida el shape. Cualquier desviación (json malformado, no
  /// objeto, `label_id` vacío/ausente, `action` ausente o fuera de ADD|REMOVE)
  /// ⇒ `FormatException` con mensaje específico. El caller traduce a copy de UI.
  static LabelStepMetadata fromJsonString(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException('label metadata: json: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('label metadata: no es objeto');
    }
    final labelId = decoded['label_id'];
    if (labelId is! String || labelId.trim().isEmpty) {
      throw const FormatException('label metadata: label_id vacío o ausente');
    }
    final action = decoded['action'];
    if (action is! String) {
      throw const FormatException('label metadata: action ausente');
    }
    return LabelStepMetadata(
      labelId: labelId,
      action: LabelStepAction.fromWire(action),
    );
  }

  /// Serializa al shape canónico del wire (snake_case). El caller pasa el
  /// resultado a `createStep` / `patchStep(metadataJson:)`.
  String toJsonString() => jsonEncode(<String, dynamic>{
    'label_id': labelId,
    'action': action.toWire(),
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelStepMetadata &&
          other.labelId == labelId &&
          other.action == action;

  @override
  int get hashCode => Object.hash(labelId, action);
}
