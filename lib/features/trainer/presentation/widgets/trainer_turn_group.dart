import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/trainer_trace.dart';
import 'trainer_change_card.dart';
import 'trainer_inspect_flow_card.dart';
import 'trainer_message_tile.dart';
import 'trainer_prompt_history_card.dart';
import 'trainer_tool_error_card.dart';

/// Pinta un turno persistido del entrenador agrupado a la gramática de la
/// traza: la burbuja del operador, el proceso plegado en UNA [TraceTimeline]
/// colapsada —con el razonamiento y las tarjetas ricas (diff, inspect_flow,
/// historial de prompt, error de tool) como cuerpos de nodo, conservando TODO
/// su comportamiento— y cada respuesta con cuerpo como burbuja limpia (sin el
/// «Razonamiento», que ya es un nodo de la traza).
class TrainerTurnGroup extends StatelessWidget {
  const TrainerTurnGroup({
    required this.turn,
    required this.trace,
    this.showProcess = true,
    super.key,
  });

  final TrainerTurn turn;
  final Trace trace;

  /// false ⇒ omite la [TraceTimeline] (la traza VIVA del turno recién cerrado
  /// sigue en pantalla y gobierna el proceso; pintar ambas lo duplicaría).
  final bool showProcess;

  @override
  Widget build(BuildContext context) {
    final nodes = capNodes(trace.nodos);
    // Sin nodos no hay timeline — ni siquiera parcial: expandir una tarjeta
    // vacía no informa nada (el turno truncado sin proceso es solo su
    // respuesta).
    final showTrace = showProcess && nodes.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (turn.user != null) TrainerMessageTile(message: turn.user!),
        if (showTrace)
          TraceTimeline(
            nodes: nodes,
            summary: _summaryLine(),
            stretch: true,
            bodyBuilder: (ctx, i) => _bodyFor(ctx, nodes, i),
          ),
        for (final r in turn.responses)
          TrainerMessageTile(message: r, showReasoning: false),
      ],
    );
  }

  /// El resumen del colapso más la duración aproximada del turno.
  String _summaryLine() {
    final base = summarizeTrace(trace);
    final d = trace.duracion;
    if (d == null || d.inSeconds <= 0) return base;
    return '$base · ${_fmtApprox(d)}';
  }

  /// Cuerpo rico del nodo `i`: el razonamiento plegable de un thinking o la
  /// tarjeta rica de un tool. Los nodos tool se alinean con
  /// [TrainerTurn.toolMessages] contando los tool previos.
  Widget? _bodyFor(BuildContext context, List<TraceNode> nodes, int i) {
    final node = nodes[i];
    if (node.kind == TraceNodeKind.thinking) {
      final text = node.detalle ?? '';
      if (text.isEmpty) return null;
      // El razonamiento como texto (mismo registro que ReasoningDisclosure) —
      // sin un segundo plegado propio: la traza ya es el colapso.
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
        ),
      );
    }
    if (node.kind == TraceNodeKind.tool) {
      final toolIdx = nodes
          .take(i)
          .where((n) => n.kind == TraceNodeKind.tool)
          .length;
      if (toolIdx < turn.toolMessages.length) {
        return _toolCardFor(turn.toolMessages[toolIdx]);
      }
    }
    return null;
  }

  /// La tarjeta rica de una fila tool — la MISMA proyección que el hilo plano
  /// usaba, reubicada como cuerpo del nodo. Las lecturas sin tarjeta y las
  /// tarjetas de cambio planas (sin nombre/diff) no rinden cuerpo: su registro
  /// ya lo da el título del nodo.
  static Widget? _toolCardFor(TrainerMessage m) {
    final inspect = TrainerInspectFlowData.fromMessage(m);
    if (inspect != null) {
      return TrainerInspectFlowCard(messageId: m.id, data: inspect);
    }
    final history = TrainerPromptHistoryData.fromMessage(m);
    if (history != null) {
      return TrainerPromptHistoryCard(messageId: m.id, data: history);
    }
    final err = TrainerToolErrorData.fromMessage(m);
    if (err != null) {
      return TrainerToolErrorCard(messageId: m.id, data: err);
    }
    final card = TrainerChangeCardData.fromMessage(m);
    if (card != null && card.expandable) {
      return TrainerChangeCard(messageId: m.id, data: card);
    }
    return null;
  }

  /// Duración aproximada, legible y SIEMPRE con «~» (no es cronometrada al ms).
  static String _fmtApprox(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '~${s}s';
    final m = d.inMinutes;
    if (m < 60) return '~${m}m';
    return '~${d.inHours}h';
  }
}
