import 'package:ataulfo/features/notes/data/datasources/notes_datasource.dart';
import 'package:ataulfo/features/notes/domain/failures/notes_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Map<String, dynamic> noteJson({
  String id = 'n1',
  String content = 'cliente VIP',
  int version = 1,
  bool isAiCreated = false,
}) => <String, dynamic>{
  'id': id,
  'org_id': 'org1',
  'content': content,
  'tags': <dynamic>['vip'],
  'is_ai_created': isAiCreated,
  'version': version,
  'created_at': '2026-06-01T10:00:00.000Z',
  'updated_at': '2026-06-01T10:00:00.000Z',
  'attachments': <dynamic>[],
};

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioNotesDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioNotesDatasource(dio);
  });

  DioException bad(int status) => DioException(
    requestOptions: RequestOptions(path: '/notes'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/notes'),
      statusCode: status,
    ),
    type: DioExceptionType.badResponse,
  );

  group('listChatNotes', () {
    test('GET /notes con bot_id + session_chat_lid del chat', () async {
      when(
        () => dio.get<List<dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: '/notes'),
          statusCode: 200,
          data: <dynamic>[noteJson(), noteJson(id: 'n2', isAiCreated: true)],
        ),
      );

      final notes = await ds.listChatNotes(botId: 'b1', chatLid: '12@lid');

      expect(notes, hasLength(2));
      expect(notes[1].isAiCreated, isTrue);
      final captured = verify(
        () => dio.get<List<dynamic>>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/notes');
      expect(captured[1], <String, dynamic>{
        'bot_id': 'b1',
        'session_chat_lid': '12@lid',
      });
    });

    test('403 → NotesForbiddenFailure', () async {
      when(
        () => dio.get<List<dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(403));

      expect(
        () => ds.listChatNotes(botId: 'b1', chatLid: 'c'),
        throwsA(isA<NotesForbiddenFailure>()),
      );
    });
  });

  group('createNote', () {
    test('POST /notes ancla la nota al chat y devuelve la creada', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/notes'),
          statusCode: 201,
          data: noteJson(),
        ),
      );

      final note = await ds.createNote(
        botId: 'b1',
        chatLid: '12@lid',
        content: 'cliente VIP',
        tags: const <String>['vip'],
        color: '#ef4444',
      );

      expect(note.id, 'n1');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/notes');
      expect(captured[1], <String, dynamic>{
        'bot_id': 'b1',
        'session_chat_lid': '12@lid',
        'content': 'cliente VIP',
        'tags': <String>['vip'],
        'color': '#ef4444',
      });
    });

    test('color/tags vacíos se omiten del body (omitempty del contrato)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/notes'),
          statusCode: 201,
          data: noteJson(),
        ),
      );

      await ds.createNote(
        botId: 'b1',
        chatLid: '12@lid',
        content: 'x',
        tags: const <String>[],
        color: '',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], <String, dynamic>{
        'bot_id': 'b1',
        'session_chat_lid': '12@lid',
        'content': 'x',
      });
    });

    test('422 → NotesValidationFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(422));

      expect(
        () => ds.createNote(
          botId: 'b1',
          chatLid: 'c',
          content: '',
          tags: const <String>[],
          color: '',
        ),
        throwsA(isA<NotesValidationFailure>()),
      );
    });
  });

  group('updateNote', () {
    test('PUT /notes/:id con version (CAS) y patch completo', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/notes/n1'),
          statusCode: 200,
          data: noteJson(version: 2),
        ),
      );

      final note = await ds.updateNote(
        id: 'n1',
        version: 1,
        content: 'editada',
        tags: const <String>['vip'],
        color: '',
      );

      expect(note.version, 2);
      final captured = verify(
        () => dio.put<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/notes/n1');
      expect(captured[1], <String, dynamic>{
        'version': 1,
        'content': 'editada',
        'tags': <String>['vip'],
        'color': '',
      });
    });

    test('409 → NotesConflictFailure (version stale)', () async {
      when(
        () => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(409));

      expect(
        () => ds.updateNote(
          id: 'n1',
          version: 1,
          content: 'x',
          tags: const <String>[],
          color: '',
        ),
        throwsA(isA<NotesConflictFailure>()),
      );
    });
  });

  group('deleteNote', () {
    test('DELETE /notes/:id?version=N (soft-delete a papelera)', () async {
      when(
        () => dio.delete<void>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(path: '/notes/n1'),
          statusCode: 204,
        ),
      );

      await ds.deleteNote(id: 'n1', version: 2);

      final captured = verify(
        () => dio.delete<void>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/notes/n1');
      expect(captured[1], <String, dynamic>{'version': '2'});
    });

    test('409 → NotesConflictFailure', () async {
      when(
        () => dio.delete<void>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(bad(409));

      expect(
        () => ds.deleteNote(id: 'n1', version: 1),
        throwsA(isA<NotesConflictFailure>()),
      );
    });
  });
}
