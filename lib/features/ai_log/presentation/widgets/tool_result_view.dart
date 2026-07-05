import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/entities/chat_analysis_envelope.dart';
import '../../domain/entities/subagent_outcome_envelope.dart';
import 'analysis_card.dart';
import 'subagent_outcome_card.dart';

/// Render del resultado de un turno role=tool: si la tool emite un envelope
/// estructurado que la app sabe pintar (análisis del chat, desenlace de
/// subagente), muestra su tarjeta; si el contenido no es ese envelope —o la
/// tool no tiene tarjeta— degrada al volcado monoespaciado. Esa degradación al
/// blob es la garantía de compatibilidad hacia atrás.
class ToolResultView extends StatelessWidget {
  const ToolResultView({super.key, required this.entry});

  final AiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    switch (entry.toolName) {
      case 'analyze_chat':
        final env = ChatAnalysisEnvelope.tryParse(entry.content);
        if (env != null) return AnalysisCard(envelope: env);
      case 'spawn_agent':
        final outcome = SubagentOutcomeEnvelope.tryParse(entry.content);
        if (outcome != null) return SubagentOutcomeCard(envelope: outcome);
    }
    return _ToolResultBlob(entry: entry);
  }
}

/// Icono por tool para el volcado de resultado: las lecturas/análisis ganan
/// identidad visual aunque caigan al blob. Decorativo (presentación pura del
/// cliente); el texto humano lo provee el servidor.
IconData _iconForTool(String toolName) {
  switch (toolName) {
    case 'read_messages':
      return Icons.mail_outline;
    case 'search_messages':
      return Icons.search;
    case 'analyze_chat':
      return Icons.insights_outlined;
    case 'spawn_agent':
      return Icons.smart_toy_outlined;
    default:
      return Icons.build_circle_outlined;
  }
}

/// Resultado de una tool: colapsado a una línea, expandible al contenido
/// completo que el modelo recibió.
class _ToolResultBlob extends StatelessWidget {
  const _ToolResultBlob({required this.entry});

  final AiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // AppCard.outline sin padding: delimita el blob con la geometría del kit
    // y su Material transparente da superficie al ListTile del ExpansionTile
    // (que no hereda así el fondo coloreado de la tarjeta de la corrida).
    return AppCard.outline(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key('ai_log.tool_result.${entry.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            0,
            AppTokens.sp3,
            AppTokens.sp3,
          ),
          leading: Icon(
            _iconForTool(entry.toolName),
            size: 18,
            color: AppTokens.text2,
          ),
          title: Text(
            'Resultado · ${entry.toolName}',
            style: textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.content.isEmpty ? '(vacío)' : entry.content,
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: AppTokens.text2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
