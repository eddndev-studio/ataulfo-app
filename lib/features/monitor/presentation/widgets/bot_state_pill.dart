import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/widgets/app_pill.dart';
import '../cubit/monitor_live_cubit.dart';
import '../live_turn_status.dart';

/// Píldora compacta de estado del bot en el header del hilo: persistente aunque
/// el operador haya scrolleado lejos del footer. Solo señala estados accionables
/// derivados de la actividad en vivo: "Pensando" (turno en curso) y el fallo de
/// la última corrida. En reposo (idle / sin eventos / no-admin) no se pinta.
/// La clasificación del feed vive en [liveTurnPhaseOf]; aquí solo se traduce la
/// fase a la variante de [AppPill] con su dot de estado.
class BotStatePill extends StatelessWidget {
  const BotStatePill({super.key});

  @override
  Widget build(BuildContext context) {
    final live = context.watch<MonitorLiveCubit>().state;
    // Turno presunto colgado: no afirmar "Pensando…" (el terminal real no llegó).
    if (live.stalled) return const SizedBox.shrink();
    final pill = switch (liveTurnPhaseOf(live.events)) {
      LiveTurnPhase.idle => null,
      LiveTurnPhase.active => const AppPill.neutral(
        key: Key('monitor.bot_state_pill'),
        label: 'Pensando…',
        dot: AppPillDot.active,
      ),
      LiveTurnPhase.failed => const AppPill.danger(
        key: Key('monitor.bot_state_pill'),
        label: 'Falló la última corrida',
        dot: AppPillDot.danger,
      ),
    };
    if (pill == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 2), child: pill);
  }
}
