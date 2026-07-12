import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/monitor_trace.dart';
import '../cubit/monitor_live_cubit.dart';
import '../live_turn_status.dart';

/// Píldora compacta de estado del bot en el header del hilo: persistente aunque
/// el operador haya scrolleado lejos del footer. Señala "Pensando" (turno en
/// curso) y el último fallo RETENIDO por el cubit — clicable: un fallo de
/// corrida abre el drill de ESA corrida (?run=); un fallo de flujo (sin runId)
/// abre Ejecuciones del chat, degradación definida que no promete traza. El
/// texto visible SIEMPRE es es-MX ([runFailureCopy]); el crudo del wire solo
/// vive en el tooltip como detalle técnico secundario. En reposo (idle / sin
/// eventos / no-admin) no se pinta.
class BotStatePill extends StatelessWidget {
  const BotStatePill({super.key, required this.botId, required this.chatLid});

  final String botId;
  final String chatLid;

  @override
  Widget build(BuildContext context) {
    final live = context.watch<MonitorLiveCubit>().state;
    // Turno presunto colgado: no afirmar "Pensando…" (el terminal real no llegó).
    if (live.stalled) return const SizedBox.shrink();
    if (liveTurnPhaseOf(live.events) == LiveTurnPhase.active) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: AppPill.neutral(
          key: Key('monitor.bot_state_pill'),
          label: 'Pensando…',
          dot: AppPillDot.active,
        ),
      );
    }
    final failure = live.failure;
    if (failure == null) return const SizedBox.shrink();
    final label = failure.isFlow
        ? 'Falló una ejecución de flujo'
        : runFailureCopy(failure.error);
    Widget pill = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openFailure(context, failure),
      child: AppPill.danger(
        key: const Key('monitor.bot_state_pill'),
        label: label,
        dot: AppPillDot.danger,
      ),
    );
    // El crudo del wire como detalle técnico secundario (long-press), jamás en
    // el texto visible.
    if (failure.error.isNotEmpty) {
      pill = Tooltip(message: failure.error, child: pill);
    }
    return Padding(padding: const EdgeInsets.only(top: 2), child: pill);
  }

  /// Fallo de corrida ⇒ la corrida como traza (?run=; sin runId degrada al log
  /// completo). Fallo de flujo ⇒ ExecutionsPage del chat.
  void _openFailure(BuildContext context, MonitorFailure failure) {
    final base = '/bots/$botId/sessions/${Uri.encodeComponent(chatLid)}';
    if (failure.isFlow) {
      context.push('$base/executions');
      return;
    }
    context.push(
      failure.runId.isEmpty
          ? '$base/ai-log'
          : '$base/ai-log?run=${Uri.encodeComponent(failure.runId)}',
    );
  }
}
