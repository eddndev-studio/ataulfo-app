/// Documento del Workspace de negocio de una plantilla (S24). En listados
/// el backend omite `content` (viaja vacío aquí); el doc completo llega al
/// abrirlo. `updatedByKind` ∈ {operator, trainer} alimenta el badge.
class WorkspaceDoc {
  const WorkspaceDoc({
    required this.name,
    required this.content,
    required this.sizeBytes,
    required this.updatedByKind,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String name;
  final String content;
  final int sizeBytes;
  final String updatedByKind;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get updatedByTrainer => updatedByKind == 'trainer';

  @override
  bool operator ==(Object other) =>
      other is WorkspaceDoc &&
      other.name == name &&
      other.content == content &&
      other.sizeBytes == sizeBytes &&
      other.updatedByKind == updatedByKind &&
      other.version == version &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    name,
    content,
    sizeBytes,
    updatedByKind,
    version,
    createdAt,
    updatedAt,
  );
}
