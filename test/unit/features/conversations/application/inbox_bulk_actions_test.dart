import 'dart:async';

import 'package:ataulfo/features/conversations/application/inbox_bulk_actions.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagesRepository extends Mock implements MessagesRepository {}

class _MockChatLabelsRepository extends Mock implements ChatLabelsRepository {}

Conversation _conversation(int index, {String? botId, String? chatLid}) =>
    Conversation(
      botId: botId ?? 'bot-$index',
      chatLid: chatLid ?? 'lid-$index',
      kind: ConversationKind.dm,
      phone: '+502 5555 $index',
      isArchived: false,
      isPinned: false,
      isMarkedUnread: false,
      mutedUntil: null,
    );

void main() {
  late _MockMessagesRepository messages;
  late _MockChatLabelsRepository chatLabels;
  late InboxBulkActions actions;

  setUp(() {
    messages = _MockMessagesRepository();
    chatLabels = _MockChatLabelsRepository();
    actions = InboxBulkActions(
      messages: messages,
      chatLabels: chatLabels,
      maxConcurrency: 4,
    );
  });

  test(
    'agrega y quita sólo la etiqueta elegida en cada conversación',
    () async {
      final targets = <Conversation>[_conversation(1), _conversation(2)];
      when(
        () => chatLabels.addToChat(any(), any(), 'vip'),
      ).thenAnswer((_) async {});
      when(
        () => chatLabels.removeFromChat(any(), any(), 'vip'),
      ).thenAnswer((_) async {});

      final added = await actions.addLabel(targets, 'vip');
      final removed = await actions.removeLabel(targets, 'vip');

      expect(added.succeededCount, 2);
      expect(removed.succeededCount, 2);
      verify(() => chatLabels.addToChat('bot-1', 'lid-1', 'vip')).called(1);
      verify(() => chatLabels.addToChat('bot-2', 'lid-2', 'vip')).called(1);
      verify(
        () => chatLabels.removeFromChat('bot-1', 'lid-1', 'vip'),
      ).called(1);
      verify(
        () => chatLabels.removeFromChat('bot-2', 'lid-2', 'vip'),
      ).called(1);
    },
  );

  test(
    'markRead tolera éxito parcial y conserva las identidades fallidas',
    () async {
      final targets = <Conversation>[
        _conversation(1),
        _conversation(2),
        _conversation(3),
      ];
      when(() => messages.markRead('bot-1', 'lid-1')).thenAnswer((_) async {});
      when(
        () => messages.markRead('bot-2', 'lid-2'),
      ).thenThrow(Exception('red'));
      when(() => messages.markRead('bot-3', 'lid-3')).thenAnswer((_) async {});

      final result = await actions.markRead(targets);

      expect(result.attemptedCount, 3);
      expect(result.succeededCount, 2);
      expect(result.failed, <InboxConversationRef>{
        const InboxConversationRef(botId: 'bot-2', chatLid: 'lid-2'),
      });
    },
  );

  test('el fan-out nunca supera cuatro operaciones simultáneas', () async {
    final targets = List<Conversation>.generate(11, _conversation);
    final release = Completer<void>();
    var active = 0;
    var peak = 0;
    when(() => messages.markRead(any(), any())).thenAnswer((_) async {
      active++;
      if (active > peak) peak = active;
      await release.future;
      active--;
    });

    final pending = actions.markRead(targets);
    await Future<void>.delayed(Duration.zero);

    expect(active, 4);
    expect(peak, 4);
    release.complete();
    final result = await pending;
    expect(result.succeededCount, 11);
    expect(peak, 4);
  });
}
