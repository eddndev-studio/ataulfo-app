import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/conditional_time_metadata.dart';
import '../../domain/entities/step.dart' as sdom;
import 'conditional_time_day_mapping.dart';

/// Resumen read-only del shape CONDITIONAL_TIME en la StepCard. Parsea
/// el metadataJson y formatea: TZ + cada ventana ("L M X J V · 09:00–18:00")
/// + las dos ramas con su paso destino RESUELTO POR ID contra [stepRefs]
/// ("Si cumple → 3. Hola…"). Un destino colgante (paso borrado fuera de
/// banda) o hacia atrás se marca en rojo — antes la tarjeta pintaba
/// "Paso #4" impasible aunque el 4 no existiera. Metadata ilegible ⇒
/// fallback honesto; filas legacy posicionales (no migradas) caen al
/// "Paso #N" clásico.
class ConditionalTimeSummary extends StatelessWidget {
  const ConditionalTimeSummary({
    super.key,
    required this.step,
    required this.textTheme,
    this.stepRefs = const <String, ({int order, String label})>{},
  });

  final sdom.Step step;
  final TextTheme textTheme;
  final Map<String, ({int order, String label})> stepRefs;

  @override
  Widget build(BuildContext context) {
    final ConditionalTimeMetadata md;
    try {
      md = ConditionalTimeMetadata.fromJsonString(step.metadataJson);
    } on FormatException {
      return Text(
        'Condicional con configuración inválida — reabre el paso para corregir.',
        key: const Key('flow_detail.step.ct_corrupt'),
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: AppTokens.danger,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Zona ${md.tz}',
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp1),
        for (final w in md.windows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.sp1),
            child: Text(
              '${_formatDays(w.days)} · ${w.from}–${w.to}',
              style: textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: AppTokens.sp1),
        _branchLine('Si cumple', md.onMatchStepId, md.onMatchOrder),
        _branchLine('Si no', md.onElseStepId, md.onElseOrder),
      ],
    );
  }

  Widget _branchLine(String prefix, String? targetId, int? legacyOrder) {
    final normal = textTheme.bodySmall?.copyWith(color: AppTokens.text2);
    final danger = textTheme.bodySmall?.copyWith(color: AppTokens.danger);
    if (targetId == null) {
      // Fila legacy posicional: sin id que resolver, posición cruda.
      final n = legacyOrder == null ? '?' : '${legacyOrder + 1}';
      return Text('$prefix → Paso #$n', style: normal);
    }
    final ref = stepRefs[targetId];
    if (ref == null) {
      return Text(
        '$prefix → (paso eliminado)',
        key: Key('flow_detail.step.ct_dangling.${step.id}'),
        style: danger,
      );
    }
    if (ref.order <= step.order) {
      return Text(
        '$prefix → ${ref.order + 1}. ${ref.label} (hacia atrás — '
        'mueve el condicional antes de su destino)',
        key: Key('flow_detail.step.ct_backward.${step.id}'),
        style: danger,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      '$prefix → ${ref.order + 1}. ${ref.label}',
      style: normal,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDays(List<int> wireDays) {
    final uiSorted = wireDays.map(wireDayToUi).toList()..sort();
    return uiSorted.map(uiDayLabel).join(' ');
  }
}
