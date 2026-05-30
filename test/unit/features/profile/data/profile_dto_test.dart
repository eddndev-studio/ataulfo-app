import 'package:ataulfo/features/profile/data/dto/profile_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileResp.fromJson', () {
    test('DM completo (con foto, nombre, muted)', () {
      final r = ProfileResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-dm',
        'kind': 'DM',
        'phone': '521555',
        'display_name': 'Alice',
        'photo_url': 'https://cdn/p.jpg',
        'is_archived': true,
        'is_pinned': false,
        'is_marked_unread': true,
        'muted_until': '2026-06-01T12:00:00Z',
        // Campos de actividad presentes pero ignorados por el perfil:
        'unread_count': 3,
        'last_message_preview': 'hola',
      });
      expect(r.chatLid, 'lid-dm');
      expect(r.kind, 'DM');
      expect(r.phone, '521555');
      expect(r.displayName, 'Alice');
      expect(r.photoUrl, 'https://cdn/p.jpg');
      expect(r.isArchived, isTrue);
      expect(r.mutedUntil, '2026-06-01T12:00:00Z');
    });

    test('GROUP mínimo (omitempty: sin phone/nombre/foto/muted)', () {
      final r = ProfileResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-grp',
        'kind': 'GROUP',
        'is_archived': false,
        'is_pinned': true,
        'is_marked_unread': false,
      });
      expect(r.kind, 'GROUP');
      expect(r.phone, isNull);
      expect(r.displayName, isNull);
      expect(r.photoUrl, isNull);
      expect(r.mutedUntil, isNull);
      expect(r.isPinned, isTrue);
    });

    test('clave obligatoria ausente → FormatException', () {
      expect(
        () => ProfileResp.fromJson(<String, dynamic>{'chat_lid': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('campo opcional con tipo equivocado → FormatException', () {
      expect(
        () => ProfileResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'is_archived': false,
          'is_pinned': false,
          'is_marked_unread': false,
          'photo_url': 123,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
