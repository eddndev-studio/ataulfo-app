import '../entities/note.dart';

/// Repositorio del cuaderno de notas (S14), vista chat-scoped.
abstract interface class NotesRepository {
  Future<List<Note>> listChatNotes({
    required String botId,
    required String chatLid,
  });

  Future<Note> createNote({
    required String botId,
    required String chatLid,
    required String content,
    required List<String> tags,
    required String color,
  });

  Future<Note> updateNote({
    required String id,
    required int version,
    required String content,
    required List<String> tags,
    required String color,
  });

  Future<void> deleteNote({required String id, required int version});
}
