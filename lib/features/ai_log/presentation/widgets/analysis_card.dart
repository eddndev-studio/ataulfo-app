import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/chat_analysis_envelope.dart';

/// Tarjeta estructurada para el resultado de `analyze_chat`: pinta el envelope
/// destilado (resumen, sentimiento, hechos, línea de tiempo) en secciones
/// legibles en vez del volcado monoespaciado. Las secciones vacías se omiten.
/// Sólo presentación: el servidor calcula el análisis, la app lo muestra.
class AnalysisCard extends StatelessWidget {
  const AnalysisCard({super.key, required this.envelope});

  final ChatAnalysisEnvelope envelope;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTokens.divider),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.insights_outlined,
                  size: 18,
                  color: AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp2),
                Expanded(
                  child: Text(
                    'Análisis del chat',
                    style: textTheme.labelMedium,
                  ),
                ),
                if (envelope.truncated)
                  const Padding(
                    key: Key('analysis_card.truncated'),
                    padding: EdgeInsets.only(left: AppTokens.sp2),
                    child: AppPill.neutral(label: 'Parcial'),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.sp2),
            Text(envelope.summary, style: textTheme.bodyMedium),
            if (envelope.sentiment.isNotEmpty) ...<Widget>[
              _label(textTheme, 'Sentimiento'),
              Align(
                alignment: Alignment.centerLeft,
                child: AppPill.neutral(label: envelope.sentiment),
              ),
            ],
            if (envelope.facts.isNotEmpty) ...<Widget>[
              _label(textTheme, 'Hechos'),
              for (final String f in envelope.facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                  child: Text('•  $f', style: textTheme.bodySmall),
                ),
            ],
            if (envelope.timeline.isNotEmpty) ...<Widget>[
              _label(textTheme, 'Línea de tiempo'),
              for (final ChatAnalysisTimelineEvent ev in envelope.timeline)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.sp1),
                  child: Text(_eventLine(ev), style: textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(TextTheme textTheme, String text) => Padding(
    padding: const EdgeInsets.only(top: AppTokens.sp3, bottom: AppTokens.sp1),
    child: Text(
      text,
      style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
    ),
  );

  String _eventLine(ChatAnalysisTimelineEvent ev) =>
      ev.at.isEmpty ? ev.event : '${ev.at}  ·  ${ev.event}';
}
