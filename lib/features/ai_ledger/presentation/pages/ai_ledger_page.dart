import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/message_timestamp.dart';
import '../../domain/entities/ledger_action.dart';
import '../../domain/failures/ai_ledger_failure.dart';
import '../bloc/ai_ledger_bloc.dart';

/// Bitácora de acciones con efecto (ADMIN+): lista cronológica de lo que el bot
/// CAMBIÓ (envío, etiqueta, flujo, nota, alerta…), resuelto a texto de negocio.
/// Distinta del ai-log: no muestra prompts ni razonamiento, sólo las acciones.
class AiLedgerPage extends StatelessWidget {
  const AiLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiLedgerBloc, AiLedgerState>(
      builder: (context, state) => switch (state) {
        AiLedgerLoading() => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        AiLedgerFailed(failure: final f) => _FailedView(failure: f),
        AiLedgerLoaded() => _LedgerView(state: state),
      },
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.state});

  final AiLedgerLoaded state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Este chat aún no tiene acciones del bot.',
            key: const Key('ai_ledger.empty'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppTokens.sp4),
      children: <Widget>[
        for (final a in state.items) ...<Widget>[
          _ActionRow(action: a),
          const SizedBox(height: AppTokens.sp2),
        ],
        if (state.nextBefore != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.sp2),
            child: AppButton.tonal(
              key: const Key('ai_ledger.load_more'),
              label: state.isLoadingMore ? 'Cargando…' : 'Cargar anteriores',
              onPressed: state.isLoadingMore
                  ? null
                  : () => context.read<AiLedgerBloc>().add(
                      const AiLedgerMoreRequested(),
                    ),
              fullWidth: true,
            ),
          ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final LedgerAction action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _iconFor(action.toolName),
            size: 20,
            color: AppTokens.chatAccent,
          ),
          const SizedBox(width: AppTokens.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  action.action,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppTokens.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (action.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.sp1),
                    child: Text(
                      action.detail,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTokens.text2,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.sp1),
                  child: MessageTimestamp(at: action.createdAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String toolName) {
  switch (toolName) {
    case 'send_message':
      return Icons.send_rounded;
    case 'send_file':
      return Icons.attach_file;
    case 'apply_label':
    case 'remove_label':
      return Icons.label_outline;
    case 'run_flow':
      return Icons.play_circle_outline;
    case 'save_note':
    case 'edit_note':
      return Icons.sticky_note_2_outlined;
    case 'notify_operator':
      return Icons.notifications_active_outlined;
    case 'react':
      return Icons.add_reaction_outlined;
    case 'mark_read':
      return Icons.done_all;
    case 'spawn_agent':
      return Icons.smart_toy_outlined;
    default:
      return Icons.bolt;
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final AiLedgerFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              ledgerFailureCopy(failure),
              key: const Key('ai_ledger.error'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
            ),
            const SizedBox(height: AppTokens.sp4),
            AppButton.tonal(
              key: const Key('ai_ledger.retry'),
              label: 'Reintentar',
              onPressed: () => context.read<AiLedgerBloc>().add(
                const AiLedgerLoadRequested(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String ledgerFailureCopy(AiLedgerFailure f) => switch (f) {
  AiLedgerNetworkFailure() => 'Sin conexión con el servidor.',
  AiLedgerForbiddenFailure() => 'Necesitas rol ADMIN para ver la bitácora.',
  AiLedgerUnknownFailure() =>
    'No pudimos cargar la bitácora. Inténtalo de nuevo.',
};
