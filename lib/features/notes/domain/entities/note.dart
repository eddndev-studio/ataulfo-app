/// Nota del cuaderno de un chat (S14). Vista chat-scoped del cliente: el
/// panel de notas del hilo lista las notas ancladas a (bot, chat), por eso
/// la entity no carga botId/sessionChatLid — el scope lo conoce el bloc.
///
/// `isAiCreated` distingue la autoría (XOR de S14): la nota la escribió el
/// agente IA (badge "IA" en el panel) o un operador humano. `version` es el
/// CAS optimista: viaja en PUT/DELETE; 409 ⇒ recargar.
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.tags,
    required this.color,
    required this.isAiCreated,
    required this.version,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final List<String> tags;

  /// Hex `#rrggbb` o `''` (sin color).
  final String color;
  final bool isAiCreated;
  final int version;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Note) return false;
    if (other.id != id ||
        other.content != content ||
        other.color != color ||
        other.isAiCreated != isAiCreated ||
        other.version != version ||
        other.updatedAt != updatedAt) {
      return false;
    }
    if (other.tags.length != tags.length) return false;
    for (var i = 0; i < tags.length; i++) {
      if (other.tags[i] != tags[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    Object.hashAll(tags),
    color,
    isAiCreated,
    version,
    updatedAt,
  );
}
