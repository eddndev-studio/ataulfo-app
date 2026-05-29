import 'package:ataulfo/features/conversations/data/dto/conversation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationResp.fromJson', () {
    test('DM completo (con phone y muted_until)', () {
      final r = ConversationResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-dm',
        'kind': 'DM',
        'phone': '5215550001',
        'is_archived': true,
        'is_pinned': false,
        'is_marked_unread': true,
        'muted_until': '2026-06-01T12:00:00Z',
      });
      expect(r.chatLid, 'lid-dm');
      expect(r.kind, 'DM');
      expect(r.phone, '5215550001');
      expect(r.isArchived, isTrue);
      expect(r.isMarkedUnread, isTrue);
      expect(r.mutedUntil, '2026-06-01T12:00:00Z');
    });

    test('GROUP mínimo (sin phone ni muted_until — omitempty del wire)', () {
      final r = ConversationResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-grp',
        'kind': 'GROUP',
        'is_archived': false,
        'is_pinned': true,
        'is_marked_unread': false,
      });
      expect(r.kind, 'GROUP');
      expect(r.phone, isNull);
      expect(r.mutedUntil, isNull);
      expect(r.isPinned, isTrue);
    });

    test('clave obligatoria ausente → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{'chat_lid': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('tipo equivocado en flag → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'is_archived': 'no', // debería ser bool
          'is_pinned': false,
          'is_marked_unread': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('phone no-String no-null → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'phone': 123,
          'is_archived': false,
          'is_pinned': false,
          'is_marked_unread': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
