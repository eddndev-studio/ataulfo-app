/// Entrada del transcript del preview. `kind` discrimina el render:
/// user/bot = burbujas del emulador; action = chip de efecto grabado
/// (etiquetaría/guardaría nota/ejecutaría flujo — nada se ejecuta).
class PreviewItem {
  const PreviewItem({
    required this.kind,
    required this.at,
    this.text = '',
    this.tool = '',
    this.summary = '',
  });

  final String kind; // user | bot | action
  final String text;
  final String tool;
  final String summary;
  final DateTime at;

  bool get isUser => kind == 'user';
  bool get isBot => kind == 'bot';
  bool get isAction => kind == 'action';

  @override
  bool operator ==(Object other) =>
      other is PreviewItem &&
      other.kind == kind &&
      other.text == text &&
      other.tool == tool &&
      other.summary == summary &&
      other.at == at;

  @override
  int get hashCode => Object.hash(kind, text, tool, summary, at);
}

/// Desenlace de un turno del preview: los items nuevos + iteraciones del
/// loop (visibilidad de costo).
class PreviewTurn {
  const PreviewTurn({required this.items, required this.iterations});

  final List<PreviewItem> items;
  final int iterations;
}
