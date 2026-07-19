import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:flutter_test/flutter_test.dart';

Conversation conversation({
  required String botId,
  required String chatLid,
  bool archived = false,
  bool markedUnread = false,
  int unreadCount = 0,
  bool needsAttention = false,
  String name = 'Comercial Rivera',
  List<ConversationLabel> labels = const <ConversationLabel>[],
}) => Conversation(
  botId: botId,
  chatLid: chatLid,
  kind: ConversationKind.dm,
  phone: '+502 5555 9012',
  displayName: name,
  isArchived: archived,
  isPinned: false,
  isMarkedUnread: markedUnread,
  mutedUntil: null,
  unreadCount: unreadCount,
  needsAttention: needsAttention,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas Guatemala',
  channelType: 'WA_UNOFFICIAL',
  channelIdentifier: '+502 2440 9012',
  labels: labels,
);

void main() {
  const vip = ConversationLabel(id: 'vip', name: 'VIP', color: '#C57B57');
  const lead = ConversationLabel(
    id: 'lead',
    name: 'Prospecto',
    color: '#4D7C6F',
  );

  test('la identidad estable incluye botId y chatLid', () {
    final first = conversation(botId: 'b1', chatLid: 'same');
    final second = conversation(botId: 'b2', chatLid: 'same');

    expect(first.stableKey, isNot(second.stableKey));
    expect(<String>{first.stableKey, second.stableKey}, hasLength(2));
  });

  test('varias etiquetas usan ALL/AND, no OR', () {
    const query = InboxQuery(labelIds: <String>{'vip', 'lead'});

    expect(
      query.matches(
        conversation(botId: 'b1', chatLid: 'both', labels: const [vip, lead]),
      ),
      isTrue,
    );
    expect(
      query.matches(
        conversation(botId: 'b1', chatLid: 'one', labels: const [vip]),
      ),
      isFalse,
    );
  });

  test('estado, canal, búsqueda y etiquetas son dimensiones AND', () {
    const query = InboxQuery(
      search: 'rivera',
      status: InboxStatus.attention,
      botId: 'b1',
      labelIds: <String>{'vip'},
    );
    final matching = conversation(
      botId: 'b1',
      chatLid: 'ok',
      needsAttention: true,
      labels: const [vip],
    );

    expect(query.matches(matching), isTrue);
    expect(
      query.matches(
        conversation(
          botId: 'b2',
          chatLid: 'wrong-channel',
          needsAttention: true,
          labels: const [vip],
        ),
      ),
      isFalse,
    );
    expect(
      query.matches(
        conversation(botId: 'b1', chatLid: 'wrong-state', labels: const [vip]),
      ),
      isFalse,
    );
  });

  test('all excluye archivadas; unread acepta contador o marca manual', () {
    expect(
      const InboxQuery().matches(
        conversation(botId: 'b1', chatLid: 'archived', archived: true),
      ),
      isFalse,
    );
    expect(
      const InboxQuery(
        status: InboxStatus.unread,
      ).matches(conversation(botId: 'b1', chatLid: 'count', unreadCount: 2)),
      isTrue,
    );
    expect(
      const InboxQuery(
        status: InboxStatus.unread,
      ).matches(conversation(botId: 'b1', chatLid: 'mark', markedUnread: true)),
      isTrue,
    );
  });

  test('copyWith puede limpiar canal y cursor explícitamente', () {
    const initial = InboxQuery(botId: 'b1', cursor: 'cursor-1');

    expect(initial.copyWith(botId: null, cursor: null), const InboxQuery());
  });
}
