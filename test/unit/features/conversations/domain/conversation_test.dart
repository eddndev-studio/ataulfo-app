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
    }) => Conversation(
      chatLid: chatLid,
      kind: kind,
      phone: phone,
      isArchived: isArchived,
      isPinned: isPinned,
      isMarkedUnread: isMarkedUnread,
      mutedUntil: mutedUntil,
    );

    test('iguales con los mismos campos', () {
      expect(make(mutedUntil: muted), make(mutedUntil: muted));
      expect(make().hashCode, make().hashCode);
    });

    test('difieren si cambia un campo', () {
      expect(make(), isNot(make(isPinned: true)));
      expect(make(), isNot(make(chatLid: 'lid-2')));
      expect(make(phone: '5215550001'), isNot(make(phone: null)));
    });
  });
}
