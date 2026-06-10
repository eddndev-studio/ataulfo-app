import 'package:dio/dio.dart';

import '../../domain/entities/note.dart';
import '../../domain/failures/notes_failure.dart';
import '../dto/note_dto.dart';
import '../mappers/notes_mapper.dart';

/// Puerto de datos del cuaderno de notas (S14), vista chat-scoped: todas las
/// operaciones trabajan sobre las notas ancladas a (bot, chat). Lanza
/// `NotesFailure` tipadas; el AuthInterceptor inyecta el Bearer.
abstract interface class NotesDatasource {
  /// `GET /notes?bot_id=&session_chat_lid=`. Activas del chat (las de IA y
  /// las del operador), más recientes primero (orden del backend).
  Future<List<Note>> listChatNotes({
    required String botId,
    required String chatLid,
  });

  /// `POST /notes` anclada al chat. 422 si el contenido no valida.
  Future<Note> createNote({
    required String botId,
    required String chatLid,
    required String content,
    required List<String> tags,
    required String color,
  });

  /// `PUT /notes/{id}` con CAS (`version`). 409 ⇒ recargar y reintentar.
  Future<Note> updateNote({
    required String id,
    required int version,
    required String content,
    required List<String> tags,
    required String color,
  });

  /// `DELETE /notes/{id}?version=N` — soft-delete a papelera. 409 si la
  /// version es stale.
  Future<void> deleteNote({required String id, required int version});
}

class DioNotesDatasource implements NotesDatasource {
  DioNotesDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<Note>> listChatNotes({
    required String botId,
    required String chatLid,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/notes',
        queryParameters: <String, dynamic>{
          'bot_id': botId,
          'session_chat_lid': chatLid,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const NotesUnknownFailure();
      }
      return NotesMapper.listToNotes(NoteResp.listFromJson(body));
    } on NotesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const NotesUnknownFailure();
    } on TypeError {
      throw const NotesUnknownFailure();
    }
  }

  @override
  Future<Note> createNote({
    required String botId,
    required String chatLid,
    required String content,
    required List<String> tags,
    required String color,
  }) => _upsert(
    () => _dio.post<Map<String, dynamic>>(
      '/notes',
      data: <String, dynamic>{
        'bot_id': botId,
        'session_chat_lid': chatLid,
        'content': content,
        // omitempty del contrato: vacíos no viajan.
        if (tags.isNotEmpty) 'tags': tags,
        if (color.isNotEmpty) 'color': color,
      },
    ),
  );

  @override
  Future<Note> updateNote({
    required String id,
    required int version,
    required String content,
    required List<String> tags,
    required String color,
  }) => _upsert(
    // El editor manda el patch completo (content+tags+color): los tres son
    // tristate en el wire, pero el sheet siempre conoce el documento entero
    // — un color/tags vacío explícito significa "vaciar", no "no tocar".
    () => _dio.put<Map<String, dynamic>>(
      '/notes/$id',
      data: <String, dynamic>{
        'version': version,
        'content': content,
        'tags': tags,
        'color': color,
      },
    ),
  );

  @override
  Future<void> deleteNote({required String id, required int version}) async {
    try {
      await _dio.delete<void>(
        '/notes/$id',
        // DELETE sin body en clientes HTTP estándar: la version del CAS
        // viaja en query string (convención S14).
        queryParameters: <String, dynamic>{'version': '$version'},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Note> _upsert(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final res = await call();
      final body = res.data;
      if (body == null) {
        throw const NotesUnknownFailure();
      }
      return NotesMapper.toEntity(NoteResp.fromJson(body));
    } on NotesFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FormatException {
      throw const NotesUnknownFailure();
    } on TypeError {
      throw const NotesUnknownFailure();
    }
  }

  NotesFailure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NotesTimeoutFailure();
      case DioExceptionType.connectionError:
        return const NotesNetworkFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 403) return const NotesForbiddenFailure();
        if (status == 404) return const NotesNotFoundFailure();
        if (status == 409) return const NotesConflictFailure();
        if (status == 422) return const NotesValidationFailure();
        if (status >= 500 && status < 600) {
          return const NotesServerFailure();
        }
        return const NotesUnknownFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const NotesUnknownFailure();
    }
  }
}
