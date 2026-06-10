/// Hilo del entrenador sobre una plantilla. Personal del operador; su
/// efecto (prompt + workspace) es compartido.
class TrainerConversation {
  const TrainerConversation({
    required this.id,
    required this.templateId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is TrainerConversation &&
      other.id == id &&
      other.templateId == templateId &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, templateId, title, createdAt, updatedAt);
}
