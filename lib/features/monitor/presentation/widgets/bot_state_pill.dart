import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/entities/monitor_event.dart';
import '../cubit/monitor_live_cubit.dart';

enum _PillKind { thinking, error }

/// Píldora compacta de estado del bot en el header del hilo: persistente aunque
/// el operador haya scrolleado lejos del footer. Solo señala estados accionables
/// derivados de la actividad en vivo: "Pensando" (turno en curso) y el fallo de
/// la última corrida. En reposo (idle / sin eventos / no-admin) no se pinta.
class BotStatePill extends StatelessWidget {
  const BotStatePill({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<MonitorLiveCubit>().state.events;
    final state = _stateOf(events);
    if (state == null) return const SizedBox.shrink();
    final (kind, label) = state;
    final color = kind == _PillKind.error ? AppTokens.danger : AppTokens.primary;
    return Container(
      key: const Key('monitor.bot_state_pill'),
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTokens.sp1),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  /// Estado accionable del último evento, o null si no hay ninguno.
  static (_PillKind, String)? _stateOf(List<MonitorEvent> events) {
    if (events.isEmpty) return null;
    switch (events.last.kind) {
      case MonitorEventKind.aiTurn:
      case MonitorEventKind.aiTool:
      case MonitorEventKind.flowStarted:
      case MonitorEventKind.flowStep:
        return (_PillKind.thinking, 'Pensando…');
      case MonitorEventKind.aiFailed:
      case MonitorEventKind.flowFailed:
        return (_PillKind.error, 'Falló la última corrida');
      case MonitorEventKind.aiCompleted:
      case MonitorEventKind.flowCompleted:
      case MonitorEventKind.alert:
      case MonitorEventKind.unknown:
      case MonitorEventKind.reconnect:
        return null;
    }
  }
}
