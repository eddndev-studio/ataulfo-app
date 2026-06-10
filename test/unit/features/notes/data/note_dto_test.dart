import 'package:ataulfo/features/notes/data/dto/note_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> canonical() => <String, dynamic>{
    'id': 'n1',
    'org_id': 'org1',
    'bot_id': 'b1',
    'session_chat_lid': '123@lid',
    'content': 'Prefiere entregas por la tarde',
    'tags': <dynamic>['preferencias', 'envíos'],
    'color': '#3b82f6',
    'is_ai_created': false,
    'created_by': 'm-1',
    'version': 2,
    'created_at': '2026-06-01T10:00:00.000Z',
    'updated_at': '2026-06-02T11:30:00.000Z',
    'attachments': <dynamic>[],
  };

  group('NoteResp.fromJson', () {
    test('parsea el shape canónico del wire (snake_case)', () {
      final resp = NoteResp.fromJson(canonical());

      expect(resp.id, 'n1');
      expect(resp.content, 'Prefiere entregas por la tarde');
      expect(resp.tags, <String>['preferencias', 'envíos']);
      expect(resp.color, '#3b82f6');
      expect(resp.isAiCreated, isFalse);
      expect(resp.version, 2);
      expect(resp.updatedAt, DateTime.utc(2026, 6, 2, 11, 30));
    });

    test('color ausente (omitempty) → cadena vacía', () {
      final json = canonical()..remove('color');
      expect(NoteResp.fromJson(json).color, '');
    });

    test('nota de IA: is_ai_created=true sin created_by', () {
      final json = canonical()
        ..['is_ai_created'] = true
        ..remove('created_by');
      expect(NoteResp.fromJson(json).isAiCreated, isTrue);
    });

    test('campo canónico ausente → FormatException (fail-loud)', () {
      for (final key in <String>['id', 'content', 'version', 'updated_at']) {
        final json = canonical()..remove(key);
        expect(
          () => NoteResp.fromJson(json),
          throwsFormatException,
          reason: 'sin $key debe fallar',
        );
      }
    });
  });

  group('NoteResp.listFromJson', () {
    test('el GET /notes devuelve array top-level (no {items})', () {
      final list = NoteResp.listFromJson(<dynamic>[canonical(), canonical()]);
      expect(list, hasLength(2));
      expect(list.first.id, 'n1');
    });

    test('lista vacía es válida', () {
      expect(NoteResp.listFromJson(<dynamic>[]), isEmpty);
    });
  });
}
