/// Hilo del asistente de plataforma (org-scoped). Personal del operador que
/// lo abre; su efecto (cambios a plantillas/bots/flujos) es de la org.
class PaConversation {
  const PaConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is PaConversation &&
      other.id == id &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt);
}
