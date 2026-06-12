/// Entrada del transcript del preview. `kind` discrimina el render:
/// user/bot = burbujas del emulador; action = chip de efecto grabado
/// (etiquetaría/guardaría nota/ejecutaría flujo — nada se ejecuta); media =
/// archivo que un flujo simulado enviaría (ref de galería + tipo de paso +
/// caption en `text`).
class PreviewItem {
  const PreviewItem({
    required this.kind,
    required this.at,
    this.text = '',
    this.tool = '',
    this.summary = '',
    this.mediaRef = '',
    this.stepType = '',
    this.delayMs = 0,
  });

  final String kind; // user | bot | action | media
  final String text;
  final String tool;
  final String summary;

  /// media: ref BARE del archivo en la galería.
  final String mediaRef;

  /// media: tipo del paso del flujo (IMAGE/VIDEO/DOCUMENT/AUDIO/PTT/STICKER).
  final String stepType;

  /// Retraso configurado del paso simulado (0 = sin retraso). El bloc lo usa
  /// para reproducir la cadencia real del flujo al revelar el turno.
  final int delayMs;

  final DateTime at;

  bool get isUser => kind == 'user';
  bool get isBot => kind == 'bot';
  bool get isAction => kind == 'action';
  bool get isMedia => kind == 'media';

  @override
  bool operator ==(Object other) =>
      other is PreviewItem &&
      other.kind == kind &&
      other.text == text &&
      other.tool == tool &&
      other.summary == summary &&
      other.mediaRef == mediaRef &&
      other.stepType == stepType &&
      other.delayMs == delayMs &&
      other.at == at;

  @override
  int get hashCode =>
      Object.hash(kind, text, tool, summary, mediaRef, stepType, delayMs, at);
}

/// Desenlace de un turno del preview: los items nuevos + iteraciones del
/// loop (visibilidad de costo). Con la ventana de acumulación abierta el
/// turno regresa de inmediato: `pending` true, items trae SOLO el user y
/// `windowEndsAt` anuncia el cierre de la ventana — el resto del turno
/// aterriza en el transcript (el cliente pollea).
class PreviewTurn {
  const PreviewTurn({
    required this.items,
    required this.iterations,
    this.pending = false,
    this.windowEndsAt,
  });

  final List<PreviewItem> items;
  final int iterations;
  final bool pending;
  final DateTime? windowEndsAt;
}

/// Transcript vivo de la sesión del preview + el estado de su ventana de
/// acumulación: `pending` mientras haya ventana abierta o turno en vuelo —
/// la señal de poll del cliente.
class PreviewTranscript {
  const PreviewTranscript({
    required this.items,
    this.pending = false,
    this.windowEndsAt,
  });

  final List<PreviewItem> items;
  final bool pending;
  final DateTime? windowEndsAt;
}
