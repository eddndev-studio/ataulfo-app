import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/subagent_outcome_envelope.dart';

/// Tarjeta estructurada para el resultado de `spawn_agent`: la única superficie
/// donde el desenlace tipado del subagente (status + summary + result, o el
/// reason del fallo/bloqueo) se ve legible en vez de como volcado crudo. El
/// `result` puede ser un blob largo, así que va en un bloque expandible. Tolera
/// summary/result/reason ausentes sin quedar en blanco (la cabecera siempre
/// muestra el estado). Sólo presentación.
class SubagentOutcomeCard extends StatelessWidget {
  const SubagentOutcomeCard({super.key, required this.envelope});

  final SubagentOutcomeEnvelope envelope;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isError = !envelope.isCompleted;
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
                Icon(
                  isError ? Icons.error_outline : Icons.smart_toy_outlined,
                  size: 18,
                  color: isError ? AppTokens.danger : AppTokens.text2,
                ),
                const SizedBox(width: AppTokens.sp2),
                Expanded(
                  child: Text('Subagente', style: textTheme.labelMedium),
                ),
                _statusPill(envelope.status),
              ],
            ),
            if (envelope.isCompleted &&
                envelope.summary.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.sp2),
              Text(envelope.summary, style: textTheme.bodyMedium),
            ],
            if (envelope.isCompleted && envelope.result.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.sp2),
              _ResultBlock(result: envelope.result),
            ],
            if (isError && envelope.reason.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppTokens.sp2),
              Text(
                envelope.reason,
                style: textTheme.bodySmall?.copyWith(color: AppTokens.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _statusPill(String status) {
    switch (status) {
      case 'completed':
        return const AppPill.neutral(label: 'Completado');
      case 'failed':
        return const AppPill.danger(label: 'Falló');
      case 'blocked':
        return const AppPill.danger(label: 'Bloqueado');
      default:
        return AppPill.neutral(label: status);
    }
  }
}

/// Bloque expandible con el `result` crudo del subagente (puede ser largo):
/// colapsado por defecto, monoespaciado al abrir, como el volcado de tools.
class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTokens.divider),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('subagent_outcome_card.result'),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppTokens.sp3),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            0,
            AppTokens.sp3,
            AppTokens.sp3,
          ),
          title: Text('Detalle', style: textTheme.labelMedium),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                result,
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
