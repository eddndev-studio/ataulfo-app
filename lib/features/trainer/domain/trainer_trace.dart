import 'dart:convert';

import 'package:flutter/material.dart' show Icons;

import '../../../core/design/tool_glyphs.dart';
import '../../../core/trace/trace.dart';
import 'entities/trainer_message.dart';
import 'entities/trainer_progress.dart';

// Reexporta el núcleo feature-agnóstico (Trace, TraceNode, summarizeTrace,
// capNodes/capNodesLive, runFailureCopy, traceStoppedSummary) para que las
// superficies que arman la traza del entrenador importen un solo módulo.
export '../../../core/trace/trace.dart';

/// Gramática de la traza del entrenador — calco de pa_trace sobre sus
/// entidades. El proceso del turno (razonamiento + tools) se agrupa en una
/// [Trace]; las tarjetas ricas (diff, inspect_flow, historial, error) NO se
/// arman aquí: quien pinta alinea [TrainerTurn.toolMessages] con los nodos
/// tool e inyecta la tarjeta como cuerpo. Los resúmenes y caps vienen del
/// núcleo — este módulo no define propios.

/// Gramática VIVA: un frame de progreso del SSE a un nodo etiqueta. thinking ⇒
/// nodo sin texto; tool ⇒ nodo con el título humano (jamás args); terminales
/// (completed/failed) ⇒ `null` (el cierre lo da el POST, no el SSE; failed
/// solo aporta la causa al resumen vía [liveTrace]).
TraceNode? nodeFromProgress(TrainerProgressEvent e) {
  if (e.isThinking) {
    return const TraceNode(
      kind: TraceNodeKind.thinking,
      titulo: 'Pensando…',
      icon: Icons.psychology_outlined,
    );
  }
  if (e.isTool) {
    return TraceNode(
      kind: TraceNodeKind.tool,
      titulo: e.toolName.isEmpty ? 'Trabajando…' : toolTitleFor(e.toolName),
      icon: toolIconFor(e.toolName),
      isError: e.toolError,
    );
  }
  return null;
}

/// Un turno agrupado del hilo del entrenador: la burbuja del operador, el
/// proceso (en la [Trace] que acompaña) y las respuestas — SIEMPRE fuera del
/// colapso. Sin confirmaciones: el catálogo del entrenador no las emite (su
/// superficie ES el contexto de edición de la plantilla).
class TrainerTurn {
  const TrainerTurn({
    this.user,
    this.responses = const <TrainerMessage>[],
    this.toolMessages = const <TrainerMessage>[],
  });

  /// Fila `user` que abrió el turno. `null` cuando la paginación partió el
  /// turno y su fila user quedó en la página anterior.
  final TrainerMessage? user;

  /// TODAS las filas `assistant` con cuerpo (texto/adjuntos), en orden: cada
  /// una se pinta como burbuja FUERA del colapso — quedarse solo con la última
  /// perdería los preámbulos intermedios («déjame revisar…»).
  final List<TrainerMessage> responses;

  /// Filas `tool` que produjeron nodos tool, en orden: quien pinta las alinea
  /// con los nodos tool para inyectar su tarjeta rica como cuerpo.
  final List<TrainerMessage> toolMessages;

  /// Identidad estable del turno (id de la primera fila que lo compone): key
  /// para que el estado de expansión de su traza no se cruce al reordenar el
  /// hilo (paginación / turno nuevo).
  String get key {
    final u = user;
    if (u != null) return u.id;
    if (responses.isNotEmpty) return responses.first.id;
    if (toolMessages.isNotEmpty) return toolMessages.first.id;
    return 'turno';
  }
}

/// Arma la traza VIVA del turno en vuelo a partir de los eventos acumulados.
/// Colapsa thinking adyacente (un mismo tramo de razonamiento puede emitir
/// varios frames), toma la causa de un `failed` que llegue antes del cierre y
/// mide del primer evento a [closedAt] (o al último evento si aún no cierra).
Trace liveTrace(
  List<TrainerProgressEvent> events, {
  DateTime? closedAt,
  bool parcial = false,
}) {
  final nodos = <TraceNode>[];
  String? fallo;
  for (final e in events) {
    if (e.isFailed && e.error.isNotEmpty) fallo = runFailureCopy(e.error);
    final n = nodeFromProgress(e);
    if (n == null) continue;
    // Un thinking pegado a otro thinking no agrega un paso: es el mismo tramo.
    if (n.kind == TraceNodeKind.thinking &&
        nodos.isNotEmpty &&
        nodos.last.kind == TraceNodeKind.thinking) {
      continue;
    }
    nodos.add(n);
  }
  Duration? dur;
  if (events.isNotEmpty) {
    dur = (closedAt ?? events.last.at).difference(events.first.at);
  }
  return Trace(nodos: nodos, parcial: parcial, duracion: dur, fallo: fallo);
}

/// Gramática PERSISTIDA: agrupa el hilo (ASC) en turnos, cada uno con su
/// [Trace]. Frontera de turno = fila `user`. Las filas `assistant` aportan un
/// nodo thinking CON su texto como detalle (F0.1 lo persiste; filas viejas
/// viajan "" y no rinden nodo) y, si traen cuerpo, una burbuja de respuesta
/// (TODAS, en orden); las `tool` aportan un nodo cuyo cuerpo será su tarjeta
/// rica. El turno más viejo puede venir sin su fila user (paginación) ⇒ se
/// marca parcial.
List<(TrainerTurn, Trace)> traceFromMessages(List<TrainerMessage> messages) {
  final out = <(TrainerTurn, Trace)>[];
  final n = messages.length;
  var i = 0;
  // Tramo inicial sin fila user: la paginación partió el turno más viejo.
  if (n > 0 && !messages[0].isUser) {
    var j = 0;
    while (j < n && !messages[j].isUser) {
      j++;
    }
    out.add(_buildTurn(messages.sublist(0, j), hasUser: false));
    i = j;
  }
  while (i < n) {
    var j = i + 1;
    while (j < n && !messages[j].isUser) {
      j++;
    }
    out.add(_buildTurn(messages.sublist(i, j), hasUser: messages[i].isUser));
    i = j;
  }
  return out;
}

(TrainerTurn, Trace) _buildTurn(
  List<TrainerMessage> rows, {
  required bool hasUser,
}) {
  final user = hasUser ? rows.first : null;
  final rest = hasUser ? rows.sublist(1) : rows;
  final nodos = <TraceNode>[];
  final toolMessages = <TrainerMessage>[];
  final responses = <TrainerMessage>[];
  for (final m in rest) {
    if (m.isAssistant) {
      if (m.thinking.isNotEmpty) {
        nodos.add(
          TraceNode(
            kind: TraceNodeKind.thinking,
            titulo: 'Razonamiento',
            icon: Icons.psychology_outlined,
            detalle: m.thinking,
          ),
        );
      }
      if (m.content.isNotEmpty || m.attachments.isNotEmpty) responses.add(m);
    } else if (m.isTool) {
      final r = _parseToolEnvelope(m.toolResultsRaw);
      nodos.add(
        TraceNode(
          kind: TraceNodeKind.tool,
          titulo: toolTitleFor(r.toolName),
          icon: toolIconFor(r.toolName),
          isError: r.errorKind.isNotEmpty,
        ),
      );
      toolMessages.add(m);
    }
  }
  Duration? dur;
  if (rows.length > 1) {
    dur = rows.last.createdAt.difference(rows.first.createdAt);
  }
  final turn = TrainerTurn(
    user: user,
    responses: responses,
    toolMessages: toolMessages,
  );
  return (turn, Trace(nodos: nodos, parcial: !hasUser, duracion: dur));
}

/// Lectura mínima del envelope del entrenador ({toolName, content} con content
/// STRING JSON doble-codificado): nombre del tool y error_kind si lo trae.
/// Cualquier shape ilegible degrada a vacíos (nodo genérico, sin error).
({String toolName, String errorKind}) _parseToolEnvelope(String? raw) {
  const empty = (toolName: '', errorKind: '');
  if (raw == null) return empty;
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return empty;
  }
  if (decoded is! Map<String, dynamic>) return empty;
  final rawTool = decoded['toolName'];
  final toolName = rawTool is String ? rawTool : '';
  var errorKind = '';
  final content = decoded['content'];
  if (content is String) {
    try {
      final inner = jsonDecode(content);
      if (inner is Map<String, dynamic> && inner['error_kind'] is String) {
        errorKind = inner['error_kind'] as String;
      }
    } on FormatException {
      // Content no-JSON: sin error detectable.
    }
  }
  return (toolName: toolName, errorKind: errorKind);
}
