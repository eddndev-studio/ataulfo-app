import 'package:flutter/material.dart' show Icons;

import '../../../core/design/tool_glyphs.dart';
import '../../../core/widgets/trace_node.dart';
import 'entities/pa_message.dart';
import 'entities/pa_progress.dart';
import 'entities/pa_tool_result.dart';

// Reexporta el vocabulario para que las superficies que arman la traza importen
// un solo módulo.
export '../../../core/widgets/trace_node.dart';

/// Copy honesto al Detener un turno en vuelo: el cancel es SOLO del cliente
/// (la suscripción SSE), el servidor pudo seguir corriendo la herramienta.
const String traceStoppedSummary = 'Detenido aquí — el servidor pudo continuar';

/// Una traza: los pasos del proceso, si está incompleta y cuánto duró.
class Trace {
  const Trace({
    required this.nodos,
    this.parcial = false,
    this.duracion,
    this.fallo,
  });

  /// Pasos SIN recortar (thinking/tool en orden). El cap visual lo aplica quien
  /// pinta, con [capNodes], para que el resumen cuente los pasos reales.
  final List<TraceNode> nodos;

  /// La traza tiene huecos: un SSE que no conectó o un turno truncado por la
  /// frontera de paginación ⇒ el resumen no inventa número de pasos.
  final bool parcial;

  /// Duración aproximada del turno (viva: primer evento→cierre; histórica:
  /// primera→última fila). `null` si no hay con qué medirla.
  final Duration? duracion;

  /// Causa es-MX del fallo del turno (si lo hubo), para el resumen del colapso.
  final String? fallo;
}

/// Un turno agrupado del hilo: la burbuja del operador, el proceso (en la
/// [Trace] que acompaña), la respuesta final y las confirmaciones —que van
/// SIEMPRE fuera del colapso—.
class PaTurn {
  const PaTurn({
    this.user,
    this.responses = const <PaMessage>[],
    this.confirmations = const <PaMessage>[],
    this.toolMessages = const <PaMessage>[],
  });

  /// Fila `user` que abrió el turno. `null` cuando la paginación partió el
  /// turno y su fila user quedó en la página anterior.
  final PaMessage? user;

  /// TODAS las filas `assistant` con cuerpo (texto/adjuntos), en orden: cada
  /// una se pinta como burbuja FUERA del colapso. El wire produce intermedios
  /// con cuerpo («déjame ver…» + tool_calls en la misma fila) y los documentos
  /// entregados cuelgan del PRIMER assistant-con-contenido — quedarse solo con
  /// la última fila perdería contenido, y una respuesta que llegue sin su fila
  /// user (turno de voz antes de la recarga) pisaría a la anterior.
  final List<PaMessage> responses;

  /// Filas `tool` de requires_confirmation: tarjetas SIEMPRE visibles fuera de
  /// la traza (posteo del literal, bloqueo del composer).
  final List<PaMessage> confirmations;

  /// Filas `tool` (no confirmación) que produjeron nodos tool, en orden: quien
  /// pinta las alinea con los nodos tool para inyectar su tarjeta de detalle.
  final List<PaMessage> toolMessages;

  /// Identidad estable del turno (id de la primera fila que lo compone): key
  /// para que el estado de expansión de su traza no se cruce al reordenar el
  /// hilo (paginación / turno nuevo).
  String get key {
    final u = user;
    if (u != null) return u.id;
    if (responses.isNotEmpty) return responses.first.id;
    if (confirmations.isNotEmpty) return confirmations.first.id;
    if (toolMessages.isNotEmpty) return toolMessages.first.id;
    return 'turno';
  }
}

/// Gramática VIVA: un frame de progreso del SSE a un nodo etiqueta. thinking ⇒
/// nodo sin texto; tool ⇒ nodo con el título humano (jamás args); terminales
/// (completed/failed) ⇒ `null` (el cierre lo da el POST, no el SSE).
TraceNode? nodeFromProgress(PaProgressEvent e) {
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

/// Arma la traza VIVA del turno en vuelo a partir de los eventos acumulados.
/// Colapsa thinking adyacente (un mismo tramo de razonamiento puede emitir
/// varios frames), toma la causa de un `failed` que llegue antes del cierre y
/// mide del primer evento a [closedAt] (o al último evento si aún no cierra).
Trace liveTrace(
  List<PaProgressEvent> events, {
  DateTime? closedAt,
  bool parcial = false,
}) {
  final nodos = <TraceNode>[];
  String? fallo;
  for (final e in events) {
    if (e.isFailed && e.error.isNotEmpty) fallo = paRunFailureCopy(e.error);
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
/// nodo thinking si traen razonamiento y, si traen cuerpo, una burbuja de
/// respuesta (TODAS, en orden); las `tool` aportan un nodo (o una
/// confirmación, fuera de la traza). El turno más viejo puede venir sin su
/// fila user (paginación) ⇒ se marca parcial.
List<(PaTurn, Trace)> traceFromMessages(List<PaMessage> messages) {
  final out = <(PaTurn, Trace)>[];
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

(PaTurn, Trace) _buildTurn(List<PaMessage> rows, {required bool hasUser}) {
  final user = hasUser ? rows.first : null;
  final rest = hasUser ? rows.sublist(1) : rows;
  final nodos = <TraceNode>[];
  final toolMessages = <PaMessage>[];
  final confirmations = <PaMessage>[];
  final responses = <PaMessage>[];
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
      final r = PaToolResult.parse(m.toolResultsRaw);
      if (r.requiresConfirmation) {
        confirmations.add(m);
      } else {
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
  }
  Duration? dur;
  if (rows.length > 1) {
    dur = rows.last.createdAt.difference(rows.first.createdAt);
  }
  final turn = PaTurn(
    user: user,
    responses: responses,
    confirmations: confirmations,
    toolMessages: toolMessages,
  );
  return (turn, Trace(nodos: nodos, parcial: !hasUser, duracion: dur));
}

/// Texto del colapso: «Falló: `<causa>`» / «Usó herramientas» (parcial) /
/// «Pensó · N pasos» / «N pasos» / «Pensó». Cuenta pasos = nodos tool (el
/// pensamiento se anota aparte); jamás inventa N en una traza parcial.
String summarizeTrace(Trace t) {
  if (t.fallo != null && t.fallo!.isNotEmpty) return 'Falló: ${t.fallo}';
  if (t.parcial) return 'Usó herramientas';
  final tools = t.nodos.where((x) => x.kind == TraceNodeKind.tool).length;
  final thought = t.nodos.any((x) => x.kind == TraceNodeKind.thinking);
  final pasos = tools == 1 ? '1 paso' : '$tools pasos';
  if (thought && tools == 0) return 'Pensó';
  if (thought) return 'Pensó · $pasos';
  return pasos;
}

/// Recorta la traza PERSISTIDA a un cap visual de 8 (orden de lectura): hasta
/// 8 se muestran tal cual; con más, los 7 primeros + un nodo sintético
/// «+N pasos más».
List<TraceNode> capNodes(List<TraceNode> nodes) {
  if (nodes.length <= 8) return nodes;
  final rest = nodes.length - 7;
  return <TraceNode>[
    ...nodes.take(7),
    TraceNode(
      kind: TraceNodeKind.masN,
      titulo: '+$rest pasos más',
      icon: Icons.more_horiz,
    ),
  ];
}

/// Recorta la traza VIVA: el paso ACTUAL (el último) debe quedar siempre
/// visible —es quien late—, así que con más de 8 sobreviven los 7 ÚLTIMOS y
/// los viejos se anuncian al inicio del carril.
List<TraceNode> capNodesLive(List<TraceNode> nodes) {
  if (nodes.length <= 8) return nodes;
  // Solo se recorta con 9+ nodos, así que los ocultos son siempre 2 o más.
  final rest = nodes.length - 7;
  return <TraceNode>[
    TraceNode(
      kind: TraceNodeKind.masN,
      titulo: '+$rest pasos anteriores',
      icon: Icons.more_horiz,
    ),
    ...nodes.skip(rest),
  ];
}

/// Copy es-MX de un fallo de corrida. El `error` del wire es libre: se detecta
/// por patrón y SIEMPRE degrada a un genérico honesto — jamás se muestra crudo.
String paRunFailureCopy(String error) {
  final e = error.toLowerCase();
  if (e.contains('deadline') ||
      e.contains('timeout') ||
      e.contains('timed out')) {
    return 'La corrida excedió el tiempo límite.';
  }
  if (e.contains('iteration') ||
      e.contains('max steps') ||
      e.contains('max_steps')) {
    return 'La corrida alcanzó el máximo de pasos.';
  }
  if (e.contains('cancel')) {
    return 'La corrida se canceló.';
  }
  if (e.contains('rate') && e.contains('limit')) {
    return 'El proveedor de IA está saturado; reintenta en un momento.';
  }
  if (e.contains('provider') ||
      e.contains('upstream') ||
      e.contains('502') ||
      e.contains('503')) {
    return 'El proveedor de IA falló.';
  }
  return 'La corrida no pudo completarse.';
}
