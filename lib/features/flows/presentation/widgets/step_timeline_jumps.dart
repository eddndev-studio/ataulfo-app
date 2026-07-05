import '../../../../core/design/widgets/app_timeline_jump.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/step.dart' as fdom;

/// Deriva los saltos de rama del timeline desde los condicionales de la
/// lista: cada CONDITIONAL_TIME sano aporta "si cumple" → destino match y
/// "si no" → destino else, con índices de LISTA (la posición visible, no
/// el `order` del wire — tras un borrado fuera de banda pueden divergir).
///
/// Solo se emiten saltos DIBUJABLES: hacia adelante y con destino
/// presente. Un destino colgante o hacia atrás no aporta salto — ese
/// estado ya lo marca en danger el resumen del propio condicional, y un
/// conector roto diría menos que ese aviso. Metadata ilegible o legacy
/// posicional (sin ids) se omite en silencio por la misma razón.
List<TimelineJump> stepTimelineJumps(List<fdom.Step> steps) {
  final indexById = <String, int>{
    for (var i = 0; i < steps.length; i++) steps[i].id: i,
  };
  final jumps = <TimelineJump>[];
  for (var i = 0; i < steps.length; i++) {
    final st = steps[i];
    if (st.type != fdom.StepType.conditionalTime) continue;
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(st.metadataJson);
    } on FormatException {
      continue;
    }
    if (!md.hasStepIdRefs) continue;
    final matchIdx = indexById[md.onMatchStepId];
    if (matchIdx != null && matchIdx > i) {
      jumps.add(TimelineJump(from: i, to: matchIdx, label: 'si cumple'));
    }
    final elseIdx = indexById[md.onElseStepId];
    if (elseIdx != null && elseIdx > i) {
      jumps.add(TimelineJump(from: i, to: elseIdx, label: 'si no'));
    }
  }
  return jumps;
}
