import 'package:flutter/material.dart' show Icons;

import '../../../core/design/tool_glyphs.dart';
import '../../../core/trace/trace.dart';
import 'entities/ai_log_entry.dart';
import 'entities/ai_run_outcome.dart';

// Reexporta el núcleo feature-agnóstico (Trace, TraceNode, summarizeTrace,
// capNodes, runFailureCopy, approxDurationLabel) para que las superficies del
// ai-log importen un solo módulo.
export '../../../core/trace/trace.dart';

/// Una corrida del ConversationLog lista para pintarse como traza: el proceso
/// (thinking/tools/system) en la [Trace], las filas fuente alineadas por nodo
/// (para inyectar cuerpos ricos) y las burbujas que van FUERA del colapso —
/// el turno del cliente y las respuestas del bot. Calco de pa_trace sobre las
/// entries persistidas del ai-log.
class AiLogRunView {
  const AiLogRunView({
    required this.trace,
    required this.nodeEntries,
    required this.users,
    required this.responses,
    required this.argsByCallId,
  });

  final Trace trace;

  /// Fila fuente del nodo `i` de [trace]: el assistant del thinking, la fila
  /// tool del nodo tool, el system del aviso. Misma longitud que los nodos.
  final List<AiLogEntry> nodeEntries;

  /// Turnos del cliente (burbujas a la derecha, fuera de la traza).
  final List<AiLogEntry> users;

  /// Filas assistant CON contenido: las respuestas del bot, fuera del colapso.
  final List<AiLogEntry> responses;

  /// Argumentos JSON de cada tool call (por id): el cuerpo del nodo tool los
  /// muestra junto al resultado de su fila tool (alineados por toolCallId).
  final Map<String, String> argsByCallId;
}

/// Gramática PERSISTIDA: las entries ASC de UNA corrida a su [AiLogRunView].
/// Las filas assistant aportan un nodo thinking si traen razonamiento (con el
/// texto como detalle) y una burbuja de respuesta si traen contenido; las tool
/// aportan un nodo con el título humano del catálogo (jamás el crudo salvo el
/// fallback «Usó `<tool>`»); las system son la voz del MOTOR (nodo atenuado).
/// [parcial] = la frontera de paginación partió la corrida: el resumen no
/// inventa N.
AiLogRunView buildRunTrace(List<AiLogEntry> asc, {bool parcial = false}) {
  final nodos = <TraceNode>[];
  final nodeEntries = <AiLogEntry>[];
  final users = <AiLogEntry>[];
  final responses = <AiLogEntry>[];
  final args = <String, String>{};
  for (final e in asc) {
    switch (e.role) {
      case AiLogRole.user:
        users.add(e);
      case AiLogRole.assistant:
        for (final c in e.toolCalls) {
          if (c.id.isNotEmpty) args[c.id] = c.argumentsJson;
        }
        if (e.reasoning.isNotEmpty) {
          nodos.add(
            TraceNode(
              kind: TraceNodeKind.thinking,
              titulo: 'Razonamiento',
              icon: Icons.psychology_outlined,
              detalle: e.reasoning,
            ),
          );
          nodeEntries.add(e);
        }
        if (e.content.isNotEmpty) {
          if (e.toolCalls.isEmpty) {
            responses.add(e);
          } else {
            // Narración a MITAD de corrida (content + tool_calls en la misma
            // fila): es un paso del proceso, no la respuesta entregada —
            // pintarla como burbuja final del Bot la haría pasar por tal y
            // perdería su posición real entre los pasos.
            nodos.add(
              TraceNode(
                kind: TraceNodeKind.thinking,
                titulo: 'Narración de la corrida',
                icon: Icons.notes_outlined,
                detalle: e.content,
              ),
            );
            nodeEntries.add(e);
          }
        }
      case AiLogRole.tool:
        nodos.add(
          TraceNode(
            kind: TraceNodeKind.tool,
            titulo: toolTitleFor(e.toolName),
            icon: toolIconFor(e.toolName),
          ),
        );
        nodeEntries.add(e);
      case AiLogRole.system:
        nodos.add(
          TraceNode(
            kind: TraceNodeKind.thinking,
            titulo: 'Aviso del sistema',
            icon: Icons.settings_outlined,
            detalle: e.content,
          ),
        );
        nodeEntries.add(e);
      case AiLogRole.unknown:
        nodos.add(
          const TraceNode(
            kind: TraceNodeKind.tool,
            titulo: 'Turno no soportado — actualiza la app.',
            icon: Icons.help_outline,
          ),
        );
        nodeEntries.add(e);
    }
  }
  Duration? dur;
  if (asc.length > 1) {
    dur = asc.last.createdAt.difference(asc.first.createdAt);
  }
  return AiLogRunView(
    trace: Trace(nodos: nodos, parcial: parcial, duracion: dur),
    nodeEntries: nodeEntries,
    users: users,
    responses: responses,
    argsByCallId: args,
  );
}

/// El nodo DESENLACE del drill: ✓ «Corrida completada» / ✗ el copy es-MX de
/// `run.error` (jamás el crudo), con la duración startedAt→endedAt SIEMPRE
/// aproximada («~»). Quien pinta lo fija DESPUÉS del cap: el desenlace jamás
/// se recorta por el «+N pasos más».
TraceNode runOutcomeNode(AiRunOutcome run) {
  final d = run.duracion;
  String withDuration(String base) {
    // El punto final del copy se recorta al componer con la duración.
    final lead = base.endsWith('.') ? base.substring(0, base.length - 1) : base;
    return d == null ? base : '$lead · ${approxDurationLabel(d)}';
  }

  if (run.failed) {
    return TraceNode(
      kind: TraceNodeKind.fallo,
      titulo: withDuration(runFailureCopy(run.error)),
      icon: Icons.error_outline,
      isError: true,
    );
  }
  return TraceNode(
    kind: TraceNodeKind.respuesta,
    titulo: withDuration('Corrida completada'),
    icon: Icons.check_circle_outline,
  );
}
