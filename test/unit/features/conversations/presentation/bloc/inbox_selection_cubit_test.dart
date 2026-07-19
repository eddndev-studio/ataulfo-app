import 'package:ataulfo/features/conversations/application/inbox_bulk_actions.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/inbox_selection_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBulkActions extends Mock implements InboxBulkActions {}

Conversation _conversation(
  int index, {
  String botId = 'bot-1',
  String? chatLid,
  String? displayName,
}) => Conversation(
  botId: botId,
  chatLid: chatLid ?? 'lid-$index',
  kind: ConversationKind.dm,
  phone: '+502 5555 $index',
  displayName: displayName ?? 'Contacto $index',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  late _MockBulkActions actions;
  late InboxSelectionCubit cubit;

  setUp(() {
    actions = _MockBulkActions();
    cubit = InboxSelectionCubit(actions: actions);
  });

  tearDown(() => cubit.close());

  test('identifica por botId + chatLid y no colisiona entre canales', () {
    final first = _conversation(1, botId: 'bot-a', chatLid: 'shared');
    final second = _conversation(2, botId: 'bot-b', chatLid: 'shared');

    expect(cubit.toggle(first), isTrue);
    expect(cubit.toggle(second), isTrue);

    expect(cubit.state.count, 2);
    expect(cubit.state.contains(first), isTrue);
    expect(cubit.state.contains(second), isTrue);
  });

  test('la selección sobrevive reorder/refresh y actualiza el snapshot', () {
    final selected = _conversation(1, displayName: 'Antes');
    final other = _conversation(2);
    cubit.toggle(selected);

    final refreshed = _conversation(1, displayName: 'Después');
    cubit.reconcileVisible(<Conversation>[other, refreshed]);

    expect(cubit.state.count, 1);
    expect(cubit.state.contains(refreshed), isTrue);
    expect(cubit.state.selected.single.displayName, 'Después');
  });

  test('sólo permite seleccionar las primeras 50 filas cargadas', () {
    final rows = List<Conversation>.generate(51, _conversation);

    for (final row in rows.take(50)) {
      expect(cubit.toggle(row), isTrue);
    }

    expect(cubit.toggle(rows.last), isFalse);
    expect(cubit.state.count, 50);
    expect(cubit.state.contains(rows.last), isFalse);
  });

  test('tras éxito parcial deselecciona éxitos y conserva fallos', () async {
    final first = _conversation(1);
    final second = _conversation(2);
    cubit
      ..toggle(first)
      ..toggle(second);
    when(() => actions.markRead(any())).thenAnswer(
      (_) async => InboxBulkResult(
        attempted: <InboxConversationRef>{
          InboxConversationRef.fromConversation(first),
          InboxConversationRef.fromConversation(second),
        },
        succeeded: <InboxConversationRef>{
          InboxConversationRef.fromConversation(first),
        },
        failed: <InboxConversationRef>{
          InboxConversationRef.fromConversation(second),
        },
      ),
    );

    final result = await cubit.markRead();

    expect(result?.succeededCount, 1);
    expect(cubit.state.count, 1);
    expect(cubit.state.contains(first), isFalse);
    expect(cubit.state.contains(second), isTrue);
  });

  test('clear descarta toda la selección', () {
    cubit
      ..toggle(_conversation(1))
      ..toggle(_conversation(2))
      ..clear();

    expect(cubit.state.count, 0);
  });
}
