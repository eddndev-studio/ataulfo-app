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
  });

  final String kind; // user | bot | action | media
  final String text;
  final String tool;
  final String summary;

  /// media: ref BARE del archivo en la galería.
  final String mediaRef;

  /// media: tipo del paso del flujo (IMAGE/VIDEO/DOCUMENT/AUDIO/PTT/STICKER).
  final String stepType;

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
      other.at == at;

  @override
  int get hashCode =>
      Object.hash(kind, text, tool, summary, mediaRef, stepType, at);
}

/// Desenlace de un turno del preview: los items nuevos + iteraciones del
/// loop (visibilidad de costo).
class PreviewTurn {
  const PreviewTurn({required this.items, required this.iterations});

  final List<PreviewItem> items;
  final int iterations;
}
