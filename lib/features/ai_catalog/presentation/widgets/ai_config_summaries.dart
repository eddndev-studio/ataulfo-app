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

/// Set cerrado de esperas del seguimiento, con su rótulo legible. Es LA fuente
/// de esos rótulos: el sheet arma sus opciones de aquí y el resumen del tile
/// los reutiliza — tile y sheet siempre dicen lo mismo.
const Map<int, String> followUpDelayLabels = <int, String>{
  30: '30 minutos',
  60: '1 hora',
  180: '3 horas',
  360: '6 horas',
  720: '12 horas',
  1440: '24 horas',
  2880: '2 días',
  4320: '3 días',
  10080: '7 días',
};

/// Rótulo de una espera: el del set cerrado, o los minutos crudos para un
/// valor fuera del set (p. ej. fijado por el agente de plataforma).
String followUpDelayLabel(int minutes) =>
    followUpDelayLabels[minutes] ?? '$minutes minutos';

/// Resumen del tile de seguimiento: apagado, o "Cada X · N intentos" con el
/// mismo tono capitalizado del resto de valores de tile.
String followUpSummary(AIConfig ai) {
  if (!ai.followUpEnabled) return 'Apagado';
  final attempts = ai.followUpMaxAttempts;
  final tries = attempts == 1 ? '1 intento' : '$attempts intentos';
  return 'Cada ${followUpDelayLabel(ai.followUpDelayMinutes)} · $tries';
}
