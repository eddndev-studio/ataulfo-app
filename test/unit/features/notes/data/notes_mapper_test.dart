import 'package:ataulfo/features/notes/data/dto/note_dto.dart';
import 'package:ataulfo/features/notes/data/mappers/notes_mapper.dart';
import 'package:ataulfo/features/notes/domain/entities/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotesMapper.toEntity', () {
    test('traduce el DTO a la entity preservando todos los campos', () {
      final resp = NoteResp(
        id: 'n1',
        content: 'cliente VIP',
        tags: const <String>['vip'],
        color: '#ef4444',
        isAiCreated: true,
        version: 3,
        updatedAt: DateTime.utc(2026, 6, 2, 11, 30),
      );

      final entity = NotesMapper.toEntity(resp);

      expect(
        entity,
        Note(
          id: 'n1',
          content: 'cliente VIP',
          tags: const <String>['vip'],
          color: '#ef4444',
          isAiCreated: true,
          version: 3,
          updatedAt: DateTime.utc(2026, 6, 2, 11, 30),
        ),
      );
    });
  });
}
