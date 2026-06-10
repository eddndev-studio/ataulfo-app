/// DTO de una Note del wire (ver `noteResp` en
/// `ataulfo-go/internal/adapters/httpnotes/dto.go`). El wire de notas es
/// snake_case (`is_ai_created`, `updated_at`), a diferencia de flows.
///
/// Fail-loud en los campos canónicos (`id`, `content`, `version`,
/// `updated_at`); tolerante en los omitempty del contrato (`color`,
/// `tags` — el backend serializa tags como `[]`, pero un null degrada a
/// vacío en vez de romper el panel).
///
/// El cliente chat-scoped no consume `org_id`/`bot_id`/`session_chat_lid`
/// (el scope lo fija la query del GET) ni `attachments` (adjuntos de nota
/// quedan fuera de este panel).
class NoteResp {
  const NoteResp({
    required this.id,
    required this.content,
    required this.tags,
    required this.color,
    required this.isAiCreated,
    required this.version,
    required this.updatedAt,
  });

  factory NoteResp.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final content = json['content'];
    final version = json['version'];
    final updatedAtRaw = json['updated_at'];
    if (id is! String ||
        content is! String ||
        version is! int ||
        updatedAtRaw is! String) {
      throw const FormatException('noteResp: clave obligatoria ausente');
    }
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (updatedAt == null) {
      throw const FormatException('noteResp: updated_at no es fecha ISO');
    }
    final tagsRaw = json['tags'];
    final tags = <String>[];
    if (tagsRaw is List<dynamic>) {
      for (final t in tagsRaw) {
        if (t is String) tags.add(t);
      }
    }
    final color = json['color'];
    final isAiCreated = json['is_ai_created'];
    return NoteResp(
      id: id,
      content: content,
      tags: tags,
      color: color is String ? color : '',
      isAiCreated: isAiCreated is bool ? isAiCreated : false,
      version: version,
      updatedAt: updatedAt,
    );
  }

  /// `GET /notes` responde un array top-level (sin wrapper `{items}`).
  static List<NoteResp> listFromJson(List<dynamic> json) => json
      .cast<Map<String, dynamic>>()
      .map(NoteResp.fromJson)
      .toList(growable: false);

  final String id;
  final String content;
  final List<String> tags;
  final String color;
  final bool isAiCreated;
  final int version;
  final DateTime updatedAt;
}
