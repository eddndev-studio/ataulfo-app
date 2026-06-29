import 'dart:convert';

/// Un hito de la línea de tiempo del análisis: cuándo y qué pasó.
class ChatAnalysisTimelineEvent {
  const ChatAnalysisTimelineEvent({required this.at, required this.event});

  final String at;
  final String event;
}

/// Envelope estructurado que el motor emite como resultado de `analyze_chat`:
/// un resumen destilado del chat (resumen, hechos, sentimiento, línea de
/// tiempo) que el operador inspecciona en el ai-log. El servidor lo calcula con
/// un modelo auxiliar; la app sólo lo pinta.
///
/// El `content` del turno role=tool llega como UNA sola cadena JSON (el motor
/// persiste el resultado crudo de la tool, sin envolverlo); por eso el parseo
/// hace un único `jsonDecode`, a diferencia del envelope doble-codificado del
/// agente de plataforma.
class ChatAnalysisEnvelope {
  const ChatAnalysisEnvelope({
    required this.summary,
    required this.facts,
    required this.sentiment,
    required this.timeline,
    required this.truncated,
  });

  final String summary;
  final List<String> facts;
  final String sentiment;
  final List<ChatAnalysisTimelineEvent> timeline;

  /// El servidor recortó el transcripto antes de analizarlo (chat largo).
  final bool truncated;

  /// Discrimina este envelope de cualquier otro resultado de tool.
  static const String _kind = 'chat_analysis';

  /// Intenta interpretar el `content` de un turno role=tool como este envelope.
  /// Devuelve null si no lo es (cadena vacía, no-JSON, no-objeto, o `kind`
  /// distinto), para que el render degrade al volcado monoespaciado.
  static ChatAnalysisEnvelope? tryParse(String content) {
    if (content.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['kind'] != _kind) return null;
    // Estructura correcta pero un campo mal tipado (p. ej. summary numérico):
    // degrada al blob en vez de crashear el render (los casts lanzarían).
    try {
      return ChatAnalysisEnvelope(
        summary: decoded['summary'] as String? ?? '',
        facts: _parseFacts(decoded['facts']),
        sentiment: decoded['sentiment'] as String? ?? '',
        timeline: _parseTimeline(decoded['timeline']),
        truncated: decoded['truncated'] as bool? ?? false,
      );
    } on TypeError {
      return null;
    }
  }

  static List<String> _parseFacts(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.map((f) => f.toString()).toList(growable: false);
  }

  static List<ChatAnalysisTimelineEvent> _parseTimeline(Object? raw) {
    if (raw is! List) return const <ChatAnalysisTimelineEvent>[];
    final out = <ChatAnalysisTimelineEvent>[];
    for (final ev in raw) {
      if (ev is Map<String, dynamic>) {
        out.add(
          ChatAnalysisTimelineEvent(
            at: ev['at']?.toString() ?? '',
            event: ev['event']?.toString() ?? '',
          ),
        );
      }
    }
    return out;
  }
}
