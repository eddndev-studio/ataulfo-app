import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/step.dart' as fdom;

/// Copy única del invariante forward-only: la usan el rechazo local del
/// drop (validación client-side) y el fallback del backend, para que
/// ambas vías hablen con la misma voz.
const String forwardOnlyReorderCopy =
    'Ese orden dejaría un condicional apuntando hacia atrás. '
    'Sus destinos deben quedar después del condicional.';

/// Valida el invariante forward-only sobre una lista de steps en el ORDEN
/// PROPUESTO (la posición en la lista ES el orden): cada condicional debe
/// quedar estrictamente ANTES de sus dos destinos por id. Espeja la regla
/// con la que el backend rechaza un reorder — validarla aquí permite
/// rechazar el drop en el acto, sin round-trip (el backend se conserva
/// como red final).
///
/// Casos que se OMITEN a propósito (no bloquean el reorder): destinos
/// colgantes (el paso ya no existe — la card los marca en danger), metadata
/// ilegible y filas legacy posicionales sin ids (imposible saber a qué paso
/// apuntan sin el order sincronizado del backend).
bool conditionalTargetsStayForward(List<fdom.Step> ordered) {
  final indexById = <String, int>{
    for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
  };
  for (var i = 0; i < ordered.length; i++) {
    final st = ordered[i];
    if (st.type != fdom.StepType.conditionalTime) continue;
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(st.metadataJson);
    } on FormatException {
      continue;
    }
    if (!md.hasStepIdRefs) continue;
    final matchIdx = indexById[md.onMatchStepId];
    if (matchIdx != null && matchIdx <= i) return false;
    final elseIdx = indexById[md.onElseStepId];
    if (elseIdx != null && elseIdx <= i) return false;
  }
  return true;
}
