import 'package:flutter/material.dart' show Icons;

import '../../../core/design/tool_glyphs.dart';
import '../../../core/trace/trace.dart';
import 'entities/monitor_event.dart';

// Reexporta el núcleo feature-agnóstico (Trace, TraceNode, summarizeTrace,
// capNodes/capNodesLive, runFailureCopy) para que las superficies del monitor
// importen un solo módulo.
export '../../../core/trace/trace.dart';

/// Gramática VIVA del hilo real — calco de pa_trace/trainer_trace sobre los
/// eventos del SSE `ai-activity`, espejo del panel web (panel-monitor). Un
/// frame a un nodo etiqueta: jamás args ni crudos; los terminales, alertas y
/// sentinels no aportan nodo (el cierre lo maneja el cubit; el fallo lo cuenta
/// la pill).
TraceNode? nodeFromMonitorEvent(MonitorEvent e) {
  switch (e.kind) {
    case MonitorEventKind.aiTurn:
      return const TraceNode(
        kind: TraceNodeKind.thinking,
        titulo: 'Pensando…',
        icon: Icons.psychology_outlined,
      );
    case MonitorEventKind.aiTool:
      return TraceNode(
        kind: TraceNodeKind.tool,
        titulo: e.toolName.isEmpty ? 'Trabajando…' : toolTitleFor(e.toolName),
        icon: toolIconFor(e.toolName),
        isError: e.toolError,
      );
    case MonitorEventKind.flowStarted:
    case MonitorEventKind.flowStep:
      return TraceNode(
        kind: TraceNodeKind.tool,
        titulo: _tituloFlujo(e),
        icon: Icons.play_circle_outline,
      );
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

/// Copy del nodo de flujo: «Ejecutando `<flujo>` · paso N» (stepIdx 1-based en
/// flow.step; 0 en STARTED ⇒ sin paso). Sin flowName (evento viejo en vuelo)
/// degrada a «Ejecutando flujo».
String _tituloFlujo(MonitorEvent e) {
  final nombre = e.flowName.trim();
  final base = nombre.isEmpty ? 'Ejecutando flujo' : 'Ejecutando $nombre';
  if (e.stepIdx >= 1) return '$base · paso ${e.stepIdx}';
  return '$base…';
}

/// Arma la traza VIVA de la actividad vigente a partir de los eventos que el
/// cubit acumuló (solo no-terminales del run/carril vigente). Colapsa thinking
/// adyacente. `parcial` se deriva de la ENTRADA — si el primer frame no es el
/// arranque real (ai.turn de la iteración 1, o flow.started), el SSE conectó a
/// mitad del turno — o viene impuesto por [truncated] (el tope del cubit
/// descartó la cabeza): en ambos casos el resumen no inventa N.
Trace monitorLiveTrace(List<MonitorEvent> events, {bool truncated = false}) {
  final nodos = <TraceNode>[];
  for (final e in events) {
    final n = nodeFromMonitorEvent(e);
    if (n == null) continue;
    // Un thinking pegado a otro thinking no agrega un paso: es el mismo tramo.
    if (n.kind == TraceNodeKind.thinking &&
        nodos.isNotEmpty &&
        nodos.last.kind == TraceNodeKind.thinking) {
      continue;
    }
    nodos.add(n);
  }
  return Trace(
    nodos: nodos,
    parcial: truncated || (events.isNotEmpty && _lateEntry(events.first)),
  );
}

/// Entrada tarde: el primer frame visto no es el arranque del turno.
bool _lateEntry(MonitorEvent first) => switch (first.kind) {
  // iteration llega 1-based en ai.turn; 0 (ausente) se trata como arranque.
  MonitorEventKind.aiTurn => first.iteration > 1,
  MonitorEventKind.aiTool => true,
  MonitorEventKind.flowStep => true,
  _ => false,
};

/// Renglón-resumen del colapso de la mini-traza: el paso ACTUAL (último nodo,
/// sin su elipsis) más el conteo de herramientas — «Pensando · 3 pasos». Una
/// traza parcial NO inventa el número; vacía anuncia «Pensando…» (aún sin
/// frames). Espejo de resumenTrazaViva del panel web.
String liveTraceSummary(Trace t) {
  if (t.nodos.isEmpty) return 'Pensando…';
  final titulo = t.nodos.last.titulo;
  final lead = titulo.endsWith('…')
      ? titulo.substring(0, titulo.length - 1)
      : titulo;
  if (t.parcial) return lead;
  final pasos = t.nodos.where((n) => n.kind == TraceNodeKind.tool).length;
  if (pasos == 0) return lead;
  return '$lead · $pasos paso${pasos == 1 ? '' : 's'}';
}
