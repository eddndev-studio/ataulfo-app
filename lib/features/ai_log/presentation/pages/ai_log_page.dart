import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/safe_bottom.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../domain/ai_log_runs.dart';
import '../../domain/ai_log_trace.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/failures/ai_log_failure.dart';
import '../bloc/ai_log_bloc.dart';
import '../widgets/ai_log_entry_tiles.dart';
import '../widgets/run_trace_group.dart';

/// Vista de observabilidad del bot (ADMIN+): el ConversationLog del chat real
/// como CORRIDAS estilo Claude — cada una colapsada a su resumen y expandible
/// a la traza del proceso ([RunTraceGroup]); la historia legacy (filas sin
/// run_id) queda plana bajo «Actividad previa», sin agrupación inventada. En
/// modo drill (?msg= / ?run=) pinta UNA corrida expandida con su desenlace.
class AiLogPage extends StatelessWidget {
  const AiLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiLogBloc, AiLogState>(
      builder: (context, state) => switch (state) {
        AiLogLoading() => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTokens.primary),
          ),
        ),
        AiLogFailed(failure: final f) => _FailedView(failure: f),
        AiLogLoaded() => _LogView(state: state),
      },
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.state});

  final AiLogLoaded state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (state.entries.isEmpty) {
      final out = state.run;
      if (state.drill && out != null) {
        // La corrida cerró SIN items en el log (falló antes de escribirlo):
        // su fila ai_runs es la única verdad — se pinta el desenlace en vez
        // de negar la actividad que la pill acaba de anunciar.
        final node = runOutcomeNode(out);
        return ListView(
          padding: const EdgeInsets.all(AppTokens.sp4),
          children: <Widget>[
            TraceTimeline(
              key: const Key('ai_log.outcome_only'),
              nodes: <TraceNode>[node],
              summary: node.titulo,
              initiallyExpanded: true,
              bodyBuilder: (ctx, i) => runOutcomeDetail(ctx, 'drill', out),
            ),
          ],
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.sp6),
          child: Text(
            'Este chat aún no tiene actividad del Asistente.',
            key: const Key('ai_log.empty'),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppTokens.text2),
          ),
        ),
      );
    }
    final (:runs, :legacy) = splitLog(state.entries);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4,
        AppTokens.sp4 + context.safeBottomInset,
      ),
      children: <Widget>[
        for (final (i, run) in runs.indexed) ...<Widget>[
          RunTraceGroup(
            run: run,
            // El desenlace es del drill: run{} describe LA corrida pedida
            // (byRun trae una sola; el guard por índice es defensa barata).
            outcome: state.drill && i == 0 ? state.run : null,
            initiallyExpanded: state.drill,
            // La corrida más vieja cargada puede estar partida por la
            // frontera de paginación: su resumen no inventa N. Con legacy en
            // la ventana, la frontera cae en el tramo plano, no aquí.
            parcial:
                !state.drill &&
                state.nextBefore != null &&
                legacy.isEmpty &&
                i == runs.length - 1,
          ),
          const SizedBox(height: AppTokens.sp3),
        ],
        if (legacy.isNotEmpty) _LegacyCard(entries: legacy),
        if (state.nextBefore != null)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.sp2),
            child: AppButton.tonal(
              key: const Key('ai_log.load_more'),
              label: state.isLoadingMore ? 'Cargando…' : 'Cargar anteriores',
              onPressed: state.isLoadingMore
                  ? null
                  : () => context.read<AiLogBloc>().add(
                      const AiLogMoreRequested(),
                    ),
              fullWidth: true,
            ),
          ),
      ],
    );
  }
}

/// La historia previa al run_id: el render plano original, en una sola
/// tarjeta rotulada — corridas con huecos no ganan una agrupación falsa.
class _LegacyCard extends StatelessWidget {
  const _LegacyCard({required this.entries});

  final List<AiLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: AppTokens.sp4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.history, size: 14, color: AppTokens.text2),
              const SizedBox(width: AppTokens.sp1),
              Text(
                'Actividad previa',
                key: const Key('ai_log.legacy'),
                style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sp3),
          for (final e in entries) AiLogEntryTile(entry: e),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure});

  final AiLogFailure failure;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final copy = switch (failure) {
      AiLogForbiddenFailure() =>
        'Tu rol no permite ver el razonamiento del Asistente. Pide acceso a un admin.',
      AiLogNetworkFailure() =>
        'Sin conexión con el servidor. Revisa tu red y reintenta.',
      AiLogUnknownFailure() =>
        'No pudimos cargar el registro del Asistente. Inténtalo de nuevo.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.sp6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy, textAlign: TextAlign.center, style: textTheme.bodyLarge),
            if (failure is! AiLogForbiddenFailure) ...<Widget>[
              const SizedBox(height: AppTokens.sp3),
              AppButton.tonal(
                label: 'Reintentar',
                onPressed: () =>
                    context.read<AiLogBloc>().add(const AiLogLoadRequested()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
