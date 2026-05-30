import 'package:ataulfo/features/conversations/data/dto/conversation_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationResp.fromJson', () {
    test('DM completo (con phone, muted_until y actividad)', () {
      final r = ConversationResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-dm',
        'kind': 'DM',
        'phone': '5215550001',
        'display_name': 'Alice',
        'is_archived': true,
        'is_pinned': false,
        'is_marked_unread': true,
        'muted_until': '2026-06-01T12:00:00Z',
        'unread_count': 4,
        'last_message_preview': 'nos vemos',
        'last_message_type': 'text',
        'last_message_direction': 'INBOUND',
        'last_message_timestamp_ms': 1700000000000,
      });
      expect(r.chatLid, 'lid-dm');
      expect(r.kind, 'DM');
      expect(r.phone, '5215550001');
      expect(r.displayName, 'Alice');
      expect(r.isArchived, isTrue);
      expect(r.isMarkedUnread, isTrue);
      expect(r.mutedUntil, '2026-06-01T12:00:00Z');
      expect(r.unreadCount, 4);
      expect(r.lastMessagePreview, 'nos vemos');
      expect(r.lastMessageType, 'text');
      expect(r.lastMessageDirection, 'INBOUND');
      expect(r.lastMessageTimestampMs, 1700000000000);
    });

    test('GROUP sin mensajes (omitempty: sin último-mensaje, unread 0)', () {
      final r = ConversationResp.fromJson(<String, dynamic>{
        'chat_lid': 'lid-grp',
        'kind': 'GROUP',
        'is_archived': false,
        'is_pinned': true,
        'is_marked_unread': false,
        'unread_count': 0,
      });
      expect(r.kind, 'GROUP');
      expect(r.phone, isNull);
      expect(r.displayName, isNull);
      expect(r.mutedUntil, isNull);
      expect(r.isPinned, isTrue);
      expect(r.unreadCount, 0);
      expect(r.lastMessagePreview, isNull);
      expect(r.lastMessageType, isNull);
      expect(r.lastMessageDirection, isNull);
      expect(r.lastMessageTimestampMs, isNull);
    });

    test('clave obligatoria ausente → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{'chat_lid': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('unread_count ausente → FormatException (no es omitempty)', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'is_archived': false,
          'is_pinned': false,
          'is_marked_unread': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('unread_count no-int → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'is_archived': false,
          'is_pinned': false,
          'is_marked_unread': false,
          'unread_count': '4',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('last_message_timestamp_ms no-int → FormatException', () {
      expect(
        () => ConversationResp.fromJson(<String, dynamic>{
          'chat_lid': 'x',
          'kind': 'DM',
          'is_archived': false,
          'is_pinned': false,
          'is_marked_unread': false,
          'unread_count': 0,
          'last_message_timestamp_ms': 'ayer',
        }),
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
          'unread_count': 0,
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
          'unread_count': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
