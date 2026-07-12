import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../domain/monitor_trace.dart';
import '../cubit/monitor_live_cubit.dart';
import '../live_turn_status.dart';

/// Mini-traza VIVA del bot en el footer del hilo: mientras el runtime está en
/// un turno pinta la [TraceTimeline] de la actividad vigente, COLAPSADA por
/// default a un renglón-resumen con latido (TypingBubble); expandida muestra
/// el carril con cap vivo (la cola sobrevive: el paso actual late) y nodos
/// solo-nombre — gramática viva, jamás args. Altura acotada: el carril vive en
/// un scroll interno para no robarle el alto al hilo. Cuando el turno cierra
/// (el cubit vació la lista) o no hay actividad, se oculta. Lo alimenta el
/// MonitorLiveCubit (SSE ADMIN+); para un no-admin el cubit nunca observa, así
/// que la lista viene vacía y el footer no se pinta.
class LiveActivity extends StatelessWidget {
  const LiveActivity({super.key});

  /// Tope de alto del footer expandido: por encima, scroll interno.
  static const double _maxHeight = 240;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorLiveCubit>().state;
    // Salud del SSE primero: si el feed se cayó, decirlo (la actividad en vivo
    // puede ir atrasada) en vez de mostrar un turno potencialmente obsoleto.
    if (state.reconnecting) {
      return _health(context);
    }
    // Turno presunto colgado: ocultar el footer en vez de seguir "pensando".
    if (state.stalled) return const SizedBox.shrink();
    // La clasificación del feed (qué mantiene un turno vivo) es compartida
    // con BotStatePill: vive en live_turn_status.
    if (liveTurnPhaseOf(state.events) != LiveTurnPhase.active) {
      return const SizedBox.shrink();
    }
    final trace = monitorLiveTrace(state.events, truncated: state.truncated);
    final summary = liveTraceSummary(trace);
    // Live region: el lector de pantalla anuncia el paso actual sin que el
    // operador tenga que enfocar el footer; el detalle visual del carril queda
    // excluido (el resumen ES la lectura).
    return Semantics(
      liveRegion: true,
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            AppTokens.sp1,
            AppTokens.sp3,
            AppTokens.sp1,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            // reverse: el fondo (el paso actual, que late) queda siempre a la
            // vista cuando el carril excede el tope.
            child: SingleChildScrollView(
              key: const Key('monitor.live_trace.scroll'),
              reverse: true,
              child: TraceTimeline(
                key: const Key('monitor.live_activity'),
                nodes: trace.nodos.isEmpty
                    ? const <TraceNode>[
                        TraceNode(
                          kind: TraceNodeKind.thinking,
                          titulo: 'Pensando…',
                          icon: Icons.psychology_outlined,
                        ),
                      ]
                    : capNodesLive(trace.nodos),
                summary: summary,
                pulseLast: true,
                collapsedLeading: const TypingBubble(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _health(BuildContext context) {
    const label = 'Reconectando…';
    return Semantics(
      key: const Key('monitor.sse_health'),
      liveRegion: true,
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.sp3,
            AppTokens.sp1,
            AppTokens.sp3,
            AppTokens.sp1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.sync_problem_outlined,
                size: 14,
                color: AppTokens.text2,
              ),
              const SizedBox(width: AppTokens.sp2),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppTokens.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
