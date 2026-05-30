import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationKind.fromWire', () {
    test('mapea los literales del contrato', () {
      expect(ConversationKind.fromWire('DM'), ConversationKind.dm);
      expect(ConversationKind.fromWire('GROUP'), ConversationKind.group);
    });

    test('valor desconocido → ArgumentError (fail-loud ante drift)', () {
      expect(
        () => ConversationKind.fromWire('CHANNEL'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Conversation value-equality', () {
    final muted = DateTime.utc(2026, 6, 1, 12);
    Conversation make({
      String chatLid = 'lid-1',
      ConversationKind kind = ConversationKind.dm,
      String? phone = '5215550001',
      bool isArchived = false,
      bool isPinned = false,
      bool isMarkedUnread = false,
      DateTime? mutedUntil,
      String? displayName,
      int unreadCount = 0,
      String? lastMessagePreview,
      String? lastMessageType,
      String? lastMessageDirection,
      int? lastMessageTimestampMs,
    }) => Conversation(
      chatLid: chatLid,
      kind: kind,
      phone: phone,
      isArchived: isArchived,
      isPinned: isPinned,
      isMarkedUnread: isMarkedUnread,
      mutedUntil: mutedUntil,
      displayName: displayName,
      unreadCount: unreadCount,
      lastMessagePreview: lastMessagePreview,
      lastMessageType: lastMessageType,
      lastMessageDirection: lastMessageDirection,
      lastMessageTimestampMs: lastMessageTimestampMs,
    );

    test('iguales con los mismos campos', () {
      expect(make(mutedUntil: muted), make(mutedUntil: muted));
      expect(make().hashCode, make().hashCode);
    });

    test('iguales incluyendo actividad (preview + no-leídos)', () {
      expect(
        make(
          unreadCount: 3,
          lastMessagePreview: 'hola',
          lastMessageType: 'text',
        ),
        make(
          unreadCount: 3,
          lastMessagePreview: 'hola',
          lastMessageType: 'text',
        ),
      );
    });

    test('difieren si cambia un campo', () {
      expect(make(), isNot(make(isPinned: true)));
      expect(make(), isNot(make(chatLid: 'lid-2')));
      expect(make(phone: '5215550001'), isNot(make(phone: null)));
    });

    test('difieren si cambia un campo de actividad', () {
      expect(make(), isNot(make(unreadCount: 1)));
      expect(make(), isNot(make(displayName: 'Alice')));
      expect(make(), isNot(make(lastMessagePreview: 'hey')));
      expect(make(), isNot(make(lastMessageType: 'image')));
      expect(make(), isNot(make(lastMessageDirection: 'OUTBOUND')));
      expect(make(), isNot(make(lastMessageTimestampMs: 1700)));
    });
  });
}
