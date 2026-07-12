import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../domain/entities/pa_tool_result.dart';
import '../../domain/pa_trace.dart';
import 'pa_message_tile.dart';
import 'pa_tool_cards.dart';

/// Pinta un turno persistido agrupado a la gramática de la traza: la burbuja
/// del operador, el proceso plegado en UNA [TraceTimeline] colapsada (con el
/// razonamiento y las tarjetas de tool como cuerpos), las confirmaciones —que
/// van SIEMPRE fuera del colapso— y cada respuesta con cuerpo como burbuja
/// limpia (sin el «Razonamiento», que ya es un nodo de la traza).
class PaTurnGroup extends StatelessWidget {
  const PaTurnGroup({
    required this.turn,
    required this.trace,
    this.onConfirm,
    this.showProcess = true,
    super.key,
  });

  final PaTurn turn;
  final Trace trace;

  /// Se reenvía a la respuesta y a las confirmaciones (autoriza un
  /// requires_confirmation). nil ⇒ la confirmación degrada a error genérico.
  final VoidCallback? onConfirm;

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
        if (turn.user != null) PaMessageTile(message: turn.user!),
        if (showTrace)
          TraceTimeline(
            nodes: nodes,
            summary: _summaryLine(),
            stretch: true,
            bodyBuilder: (ctx, i) => _bodyFor(ctx, nodes, i),
          ),
        // Las confirmaciones nunca se pliegan: su lógica (posteo del literal,
        // bloqueo del composer) queda intacta y siempre a la vista.
        for (final conf in turn.confirmations)
          PaMessageTile(message: conf, onConfirm: onConfirm),
        for (final r in turn.responses)
          PaMessageTile(message: r, onConfirm: onConfirm, showReasoning: false),
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
  /// tarjeta de detalle de un tool. Los nodos tool se alinean con
  /// [PaTurn.toolMessages] contando los tool previos.
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
        final result = PaToolResult.parse(
          turn.toolMessages[toolIdx].toolResultsRaw,
        );
        if (result.hasDetail) return PaToolDetail(result: result);
      }
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
