/// Resúmenes de una línea de los campos de [AIConfig] que el editor pinta en
/// sus stat tiles. Son helpers de presentación puros (config → copy).
library;

import '../../../../core/ai/ai_config.dart';
import '../../../../core/ai/tool_groups.dart';

/// Conteo legible de etiquetas de silencio seleccionadas.
String silenceLabelsSummary(int n) => switch (n) {
  0 => 'Ninguna',
  1 => '1 etiqueta',
  _ => '$n etiquetas',
};

/// Resumen "habilitados/total grupos". Solo cuenta grupos conocidos como
/// apagados (un id desconocido no reduce el conteo de habilitados).
String toolGroupsSummary(List<String> disabled) {
  final total = ToolGroup.values.length;
  final known = ToolGroup.values.map((g) => g.wire).toSet();
  final knownDisabled = disabled.where(known.contains).length;
  final enabled = total - knownDisabled;
  return enabled == total ? 'Todos habilitados' : '$enabled/$total grupos';
}

/// Resumen del tile de seguimiento: apagado, o "cada X · N intentos".
String followUpSummary(AIConfig ai) {
  if (!ai.followUpEnabled) return 'Apagado';
  final m = ai.followUpDelayMinutes;
  final delay = m >= 1440 && m % 1440 == 0
      ? '${m ~/ 1440} d'
      : m >= 60 && m % 60 == 0
      ? '${m ~/ 60} h'
      : '$m min';
  return 'cada $delay · ${ai.followUpMaxAttempts} intento(s)';
}
