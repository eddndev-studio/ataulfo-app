import 'package:flutter/foundation.dart';

/// Entrada de la allowlist de modelos del entrenador. El operador elige SOLO
/// el modelo; el resto de la config (razonamiento, temperatura) la fija la
/// plataforma server-side.
class TrainerModelOption {
  const TrainerModelOption({required this.id, required this.label});

  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is TrainerModelOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Allowlist completa + el modelo default de la plataforma (informativo:
/// el selector lo marca; elegir "default" manda el turno SIN modelo y el
/// server usa su config).
class TrainerModels {
  const TrainerModels({required this.options, required this.defaultId});

  final List<TrainerModelOption> options;
  final String defaultId;

  @override
  bool operator ==(Object other) =>
      other is TrainerModels &&
      listEquals(other.options, options) &&
      other.defaultId == defaultId;

  @override
  int get hashCode => Object.hash(Object.hashAll(options), defaultId);
}
