import '../../domain/entities/note.dart';
import '../dto/note_dto.dart';

/// Traduce DTOs del cuaderno de notas a entidades de dominio.
class NotesMapper {
  const NotesMapper._();

  static Note toEntity(NoteResp resp) => Note(
    id: resp.id,
    content: resp.content,
    tags: resp.tags,
    color: resp.color,
    isAiCreated: resp.isAiCreated,
    version: resp.version,
    updatedAt: resp.updatedAt,
  );

  static List<Note> listToNotes(List<NoteResp> resps) =>
      resps.map(toEntity).toList(growable: false);
}
