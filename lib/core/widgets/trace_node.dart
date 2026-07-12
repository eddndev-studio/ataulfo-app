import 'package:flutter/widgets.dart';

/// El vocabulario de un paso de una traza estilo Claude. Vive en `core` (no en
/// una feature) porque lo comparten el componente visual [TraceTimeline] y las
/// gramáticas por-feature que lo alimentan (asistente, entrenador, hilo real):
/// así el widget no depende de ninguna feature.

/// Naturaleza de un nodo de la traza.
enum TraceNodeKind {
  /// El modelo razonó. En vivo es una etiqueta sin texto; persistido lleva el
  /// razonamiento como cuerpo plegable.
  thinking,

  /// El modelo usó una herramienta.
  tool,

  /// La respuesta final del turno. Parte del vocabulario para superficies que
  /// anclan la respuesta como nodo; el asistente la pinta fuera del colapso.
  respuesta,

  /// El turno falló.
  fallo,

  /// Nodo sintético de recorte: «+N pasos más» cuando la traza excede el cap.
  masN,
}

/// Un paso de la traza: ícono + título y, opcionalmente, un detalle de texto
/// (el cuerpo rico —tarjetas, razonamiento plegable— lo inyecta el llamador).
class TraceNode {
  const TraceNode({
    required this.kind,
    required this.titulo,
    required this.icon,
    this.detalle,
    this.isError = false,
  });

  final TraceNodeKind kind;
  final String titulo;
  final IconData icon;

  /// Detalle de texto del nodo (p. ej. el razonamiento de un nodo thinking
  /// persistido). `null` cuando el cuerpo lo aporta el llamador o no hay.
  final String? detalle;

  /// El paso terminó en error: el nodo se tiñe en `danger`.
  final bool isError;
}
