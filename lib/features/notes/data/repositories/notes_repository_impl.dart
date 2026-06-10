import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_datasource.dart';

/// Delegación directa al datasource: las notas no llevan cache local (el
/// panel recarga al abrir; el CAS del backend resuelve la concurrencia).
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl({required NotesDatasource datasource})
    : _ds = datasource;

  final NotesDatasource _ds;

  @override
  Future<List<Note>> listChatNotes({
    required String botId,
    required String chatLid,
  }) => _ds.listChatNotes(botId: botId, chatLid: chatLid);

  @override
  Future<Note> createNote({
    required String botId,
    required String chatLid,
    required String content,
    required List<String> tags,
    required String color,
  }) => _ds.createNote(
    botId: botId,
    chatLid: chatLid,
    content: content,
    tags: tags,
    color: color,
  );

  @override
  Future<Note> updateNote({
    required String id,
    required int version,
    required String content,
    required List<String> tags,
    required String color,
  }) => _ds.updateNote(
    id: id,
    version: version,
    content: content,
    tags: tags,
    color: color,
  );

  @override
  Future<void> deleteNote({required String id, required int version}) =>
      _ds.deleteNote(id: id, version: version);
}
