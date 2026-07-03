import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/bot.dart';
import '../bloc/bot_detail_bloc.dart';
import 'bot_toggle_row.dart';

/// Sección "En grupos" del detalle de un Bot: dos gates planos para los chats
/// de GRUPO de WhatsApp — apagar la IA y apagar los flujos disparados por
/// mensaje.
///
/// A diferencia del toggle de IA (que resuelve la IA EFECTIVA contra la
/// plantilla), estos flags son planos del bot: el switch refleja el valor tal
/// cual, sin fetch ni degradación. `true` = el comportamiento correspondiente
/// NO actúa en grupos; las respuestas manuales del operador nunca se afectan.
class BotGroupGates extends StatelessWidget {
  const BotGroupGates({super.key, required this.bot, required this.isMutating});

  final Bot bot;

  /// Hay un PUT en vuelo → los switches quedan inhabilitados.
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bloc = context.read<BotDetailBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('En grupos', style: textTheme.titleSmall),
        const SizedBox(height: AppTokens.sp1),
        Text(
          'En los chats de grupo de WhatsApp puedes apagar la IA y los flujos '
          'disparados por mensaje de este bot. Los flujos disparados por '
          'etiqueta o lanzados a mano, y las respuestas manuales del operador, '
          'no se ven afectados.',
          style: textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
        const SizedBox(height: AppTokens.sp4),
        BotToggleRow(
          switchKey: const Key('bot_detail.group_chats_ai'),
          label: 'Desactivar IA en grupos',
          caption: bot.groupChatsAiDisabled
              ? 'La IA no responde en los chats de grupo.'
              : 'La IA responde también en los chats de grupo.',
          value: bot.groupChatsAiDisabled,
          onChanged: isMutating
              ? null
              : (v) =>
                    bloc.add(BotDetailUpdateRequested(groupChatsAiDisabled: v)),
        ),
        const SizedBox(height: AppTokens.sp4),
        BotToggleRow(
          switchKey: const Key('bot_detail.group_chats_flows'),
          label: 'Desactivar flujos en grupos',
          caption: bot.groupChatsFlowsDisabled
              ? 'Los flujos disparados por mensaje no se activan en grupos.'
              : 'Los flujos disparados por mensaje se activan también en '
                    'grupos.',
          value: bot.groupChatsFlowsDisabled,
          onChanged: isMutating
              ? null
              : (v) => bloc.add(
                  BotDetailUpdateRequested(groupChatsFlowsDisabled: v),
                ),
        ),
      ],
    );
  }
}
