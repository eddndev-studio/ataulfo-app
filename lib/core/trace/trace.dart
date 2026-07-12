import 'package:flutter/material.dart' show Icons;

import '../widgets/trace_node.dart';

// Reexporta el vocabulario: quien arma o resume una traza habla en TraceNode.
export '../widgets/trace_node.dart';

/// Lo feature-agnóstico de una traza estilo Claude: el modelo [Trace], su
/// resumen, los caps visuales y el copy de fallos de corrida. Las gramáticas
/// por-feature (asistente, entrenador, hilo real) viven en su feature y
/// alimentan estas piezas — aquí NO se conoce ningún wire.

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

/// Duración aproximada legible, SIEMPRE con «~» (no es cronometrada al ms):
/// «~42s», «~3m», «~2h». Mismo formato que usan las trazas del asistente y el
/// entrenador para el sufijo del resumen.
String approxDurationLabel(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '~${s}s';
  final m = d.inMinutes;
  if (m < 60) return '~${m}m';
  return '~${d.inHours}h';
}

/// Copy es-MX de un fallo de corrida. El `error` del wire es libre: se detecta
/// por patrón y SIEMPRE degrada a un genérico honesto — jamás se muestra crudo.
String runFailureCopy(String error) {
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
