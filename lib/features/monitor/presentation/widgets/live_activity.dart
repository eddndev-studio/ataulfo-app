import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/typing_bubble.dart';
import '../../domain/entities/monitor_event.dart';
import '../cubit/monitor_live_cubit.dart';

/// Footer de actividad EN VIVO del bot en un hilo: mientras el runtime está en
/// un turno (último evento no-terminal) muestra una burbuja "pensando" + qué
/// está haciendo (qué tool, o ejecutando un flujo). Cuando el turno cierra
/// (aiCompleted/aiFailed) o no hay actividad, se oculta. Lo alimenta el
/// MonitorLiveCubit (SSE ADMIN+); para un no-admin el cubit nunca observa, así
/// que la lista viene vacía y el footer no se pinta.
class LiveActivity extends StatelessWidget {
  const LiveActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MonitorLiveCubit>().state;
    // Salud del SSE primero: si el feed se cayó, decirlo (la actividad en vivo
    // puede ir atrasada) en vez de mostrar un turno potencialmente obsoleto.
    if (state.reconnecting) {
      return _row(
        context,
        key: const Key('monitor.sse_health'),
        leading: const Icon(
          Icons.sync_problem_outlined,
          size: 14,
          color: AppTokens.text2,
        ),
        label: 'Reconectando…',
      );
    }
    // Turno presunto colgado: ocultar el footer en vez de seguir "pensando".
    if (state.stalled) return const SizedBox.shrink();
    final label = _activeLabel(state.events);
    if (label == null) return const SizedBox.shrink();
    return _row(
      context,
      key: const Key('monitor.live_activity'),
      leading: const TypingBubble(),
      label: label,
    );
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required Widget leading,
    required String label,
  }) {
    // Live region: el lector de pantalla anuncia el cambio (qué hace el bot)
    // sin que el operador tenga que enfocar el footer. El label semántico es el
    // mismo texto visible; el ícono es decorativo.
    return Semantics(
      key: key,
      liveRegion: true,
      container: true,
      label: label,
      child: ExcludeSemantics(child: _visualRow(context, leading, label)),
    );
  }

  Widget _visualRow(BuildContext context, Widget leading, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sp3,
        AppTokens.sp1,
        AppTokens.sp3,
        AppTokens.sp1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          leading,
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
    );
  }

  /// Etiqueta del turno en curso, o null si no hay turno activo. Se mira el
  /// ÚLTIMO evento: un terminal (completed/failed) cierra el turno; los
  /// no-terminales (turn/tool/flow) lo mantienen vivo.
  static String? _activeLabel(List<MonitorEvent> events) {
    if (events.isEmpty) return null;
    final last = events.last;
    switch (last.kind) {
      case MonitorEventKind.aiTool:
        return last.toolName.isNotEmpty
            ? 'Usando ${last.toolName}…'
            : 'Trabajando…';
      case MonitorEventKind.aiTurn:
        return 'Pensando…';
      case MonitorEventKind.flowStarted:
      case MonitorEventKind.flowStep:
        return 'Ejecutando un flujo…';
      case MonitorEventKind.aiCompleted:
      case MonitorEventKind.aiFailed:
      case MonitorEventKind.flowCompleted:
      case MonitorEventKind.flowFailed:
      case MonitorEventKind.alert:
      case MonitorEventKind.unknown:
      case MonitorEventKind.reconnect:
      case MonitorEventKind.connected:
        return null;
    }
  }
}
