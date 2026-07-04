import 'package:flutter/foundation.dart';

/// Entrada de la allowlist de modelos del asistente de plataforma. El operador
/// elige SOLO el modelo; el resto de la config (razonamiento, temperatura) la
/// fija la plataforma server-side.
class PaModelOption {
  const PaModelOption({
    required this.id,
    required this.label,
    this.imageInput,
    this.pdfInput,
  });

  final String id;
  final String label;

  /// Modalidad declarada por el server: ¿el modelo VE la imagen nativamente?
  /// `null` = el wire no lo declara (contrato viejo) — sin aviso de modalidad.
  final bool? imageInput;

  /// ¿El modelo lee el PDF nativamente? `null` = desconocido (sin aviso).
  final bool? pdfInput;

  @override
  bool operator ==(Object other) =>
      other is PaModelOption &&
      other.id == id &&
      other.label == label &&
      other.imageInput == imageInput &&
      other.pdfInput == pdfInput;

  @override
  int get hashCode => Object.hash(id, label, imageInput, pdfInput);
}

/// Allowlist completa + el modelo default de la plataforma (informativo: el
/// selector lo marca; elegir "default" manda el turno SIN modelo y el server
/// usa su config).
class PaModels {
  const PaModels({required this.options, required this.defaultId});

  final List<PaModelOption> options;
  final String defaultId;

  @override
  bool operator ==(Object other) =>
      other is PaModels &&
      listEquals(other.options, options) &&
      other.defaultId == defaultId;

  @override
  int get hashCode => Object.hash(Object.hashAll(options), defaultId);
}
