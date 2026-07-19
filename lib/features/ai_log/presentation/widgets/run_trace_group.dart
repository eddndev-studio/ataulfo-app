import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_disclosure_tile.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/assistant_markdown.dart';
import '../../../../core/widgets/trace_timeline.dart';
import '../../domain/ai_log_runs.dart';
import '../../domain/ai_log_trace.dart';
import '../../domain/entities/ai_log_entry.dart';
import '../../domain/entities/ai_run_outcome.dart';
import '../ai_log_format.dart';
import 'ai_log_entry_tiles.dart';
import 'tool_result_view.dart';

/// Una corrida del motor como TURNO estilo Claude: header con
/// modelo/tokens/hora, la burbuja del cliente, el PROCESO colapsado a su
/// resumen ([summarizeTrace] + duración «~») y expandible a traza (cap
/// persistido por la cabeza), y las respuestas del bot fuera del colapso. En
/// el drill (`outcome` presente) la traza nace expandida y cierra con el nodo
/// DESENLACE, fijado DESPUÉS del cap: jamás lo recorta el «+N pasos más».
class RunTraceGroup extends StatelessWidget {
  const RunTraceGroup({
    super.key,
    required this.run,
    this.outcome,
    this.initiallyExpanded = false,
    this.parcial = false,
  });

  final AiLogRun run;

  /// Desenlace persistido (solo el drill lo trae); null ⇒ sin nodo de cierre.
  final AiRunOutcome? outcome;

  final bool initiallyExpanded;

  /// La frontera de paginación partió esta corrida (la más vieja cargada):
  /// su resumen no inventa N.
  final bool parcial;

  /// Porcentaje redondeado del prompt servido desde caché; 0 sin caché (o con
  /// una proporción que redondea a cero, que el header omite).
  int get _cachePct => run.promptTokens > 0
      ? (run.cachedTokens * 100 / run.promptTokens).round().clamp(0, 100)
      : 0;

  @override
  Widget build(BuildContext context) {
    final view = buildRunTrace(run.entries, parcial: parcial);
    final process = capNodes(view.trace.nodos);
    final out = outcome;
    final nodes = <TraceNode>[...process, if (out != null) runOutcomeNode(out)];
    return AppCard(
      padding: AppTokens.sp4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(context),
          const SizedBox(height: AppTokens.sp3),
          for (final u in view.users)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.sp3),
              child: AiLogTurnBubble(
                icon: Icons.person_outline,
                title: 'Cliente',
                mine: true,
                child: Text(
                  u.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (nodes.isNotEmpty)
            TraceTimeline(
              key: Key('ai_log.run_trace.${run.runId}'),
              nodes: nodes,
              summary: _summary(view.trace),
              initiallyExpanded: initiallyExpanded,
              bodyBuilder: (context, i) => _bodyFor(context, view, nodes, i),
            ),
          for (final r in view.responses)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp3),
              child: AiLogTurnBubble(
                icon: Icons.smart_toy_outlined,
                title: 'Asistente',
                mine: false,
                child: AssistantMarkdown(data: r.content),
              ),
            ),
        ],
      ),
    );
  }

  /// El resumen del colapso más la duración aproximada. Sin pasos de proceso
  /// (corrida directa a la respuesta) resume el desenlace o el turno.
  String _summary(Trace trace) {
    final base = trace.nodos.isNotEmpty
        ? summarizeTrace(trace)
        : (outcome?.failed ?? false)
        ? 'Falló la corrida'
        : 'Respondió directo';
    final d = outcome?.duracion ?? trace.duracion;
    if (d == null || d.inSeconds <= 0) return base;
    return '$base · ${approxDurationLabel(d)}';
  }

  /// Cuerpo rico del nodo `i`: el razonamiento/aviso como texto, la tarjeta de
  /// resultado (+ argumentos) de un tool, y el detalle técnico del desenlace.
  /// El cap conserva la CABEZA, así que los índices del carril mapean directo
  /// a [AiLogRunView.nodeEntries] hasta el «+N».
  Widget? _bodyFor(
    BuildContext context,
    AiLogRunView view,
    List<TraceNode> nodes,
    int i,
  ) {
    final node = nodes[i];
    final out = outcome;
    if (out != null && i == nodes.length - 1) return _outcomeBody(context, out);
    if (node.kind == TraceNodeKind.masN) return null;
    if (i >= view.nodeEntries.length) return null;
    final entry = view.nodeEntries[i];
    switch (node.kind) {
      case TraceNodeKind.thinking:
        final text = node.detalle ?? '';
        if (text.isEmpty) return null;
        // El texto plano (mismo registro que ReasoningDisclosure) — sin un
        // segundo plegado propio: la traza ya es el colapso.
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTokens.text2),
          ),
        );
      case TraceNodeKind.tool:
        if (entry.role != AiLogRole.tool) return null;
        final args = view.argsByCallId[entry.toolCallId];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (args != null && args.isNotEmpty)
              AiLogToolCallTile(
                call: AiToolCall(
                  id: entry.toolCallId,
                  name: entry.toolName,
                  argumentsJson: args,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.sp2),
              child: ToolResultView(entry: entry),
            ),
          ],
        );
      case TraceNodeKind.respuesta:
      case TraceNodeKind.fallo:
      case TraceNodeKind.masN:
        return null;
    }
  }

  Widget? _outcomeBody(BuildContext context, AiRunOutcome out) =>
      runOutcomeDetail(context, run.runId, out);

  Widget _header(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = run.startedAt.toLocal();
    final stamp =
        '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Wrap(
      spacing: AppTokens.sp2,
      runSpacing: AppTokens.sp1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          stamp,
          style: textTheme.labelSmall?.copyWith(color: AppTokens.text2),
        ),
        if (run.model.isNotEmpty) AppPill.outline(label: run.model),
        // Tokens de entrada al modelo (prompt) y generados (completion),
        // abreviados; las flechas comunican la dirección sin texto extra.
        if (run.promptTokens > 0)
          AppPill.neutral(
            icon: Icons.arrow_upward,
            label: formatTokensCompact(run.promptTokens),
          ),
        if (run.completionTokens > 0)
          AppPill.neutral(
            icon: Icons.arrow_downward,
            label: formatTokensCompact(run.completionTokens),
          ),
        // Proporción del prompt servida desde caché (más barata). Una
        // proporción real que redondea a 0% se omite: "caché 0%" leería
        // como sin-caché.
        if (_cachePct > 0) AppPill.neutral(label: 'caché $_cachePct%'),
        if (run.costMicroUsd > 0)
          AppPill.outline(label: formatMicroUsd(run.costMicroUsd)),
        // Corridas viejas sin desglose prompt/completion: se conserva el
        // pill único de total para no perder el dato.
        if (run.promptTokens == 0 &&
            run.completionTokens == 0 &&
            run.totalTokens > 0)
          AppPill.neutral(label: '${run.totalTokens} tokens'),
      ],
    );
  }
}

/// Cuerpo del nodo desenlace: el crudo del wire SOLO como detalle técnico
/// secundario, plegado — el título ya trae el copy es-MX. Compartido entre la
/// tarjeta de corrida y la vista de desenlace-sin-items del drill.
Widget? runOutcomeDetail(BuildContext context, String runId, AiRunOutcome out) {
  if (!out.failed || out.error.isEmpty) return null;
  return AppDisclosureTile(
    key: Key('ai_log.outcome_detail.$runId'),
    icon: Icons.terminal,
    title: 'Detalle técnico',
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        out.error,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: AppTokens.text2,
        ),
      ),
    ),
  );
}
