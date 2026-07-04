import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessagesRepository {}

Future<void> tick() => Future<void>.delayed(Duration.zero);

/// `MessagesClearHistoryRequested` — vaciar el historial del chat (S07
/// RF#10): delega en el repo (que ya limpia la verdad local write-through; el
/// watch re-emite el hilo vacío solo) y un fallo se anuncia tipado por el
/// side-channel de correcciones, igual que edit/delete.
void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  MessagesBloc build() =>
      MessagesBloc(repo: repo, botId: 'b1', chatLid: 'lid-1');

  test('delega en repo.clearHistory', () async {
    when(() => repo.clearHistory(any(), any())).thenAnswer((_) async {});
    final bloc = build();

    bloc.add(const MessagesClearHistoryRequested());
    await tick();

    verify(() => repo.clearHistory('b1', 'lid-1')).called(1);
    await bloc.close();
  });

  test('fallo tipado → correctionFailures', () async {
    when(
      () => repo.clearHistory(any(), any()),
    ).thenThrow(const MessagesForbiddenFailure());
    final bloc = build();
    final fails = <MessagesFailure>[];
    final sub = bloc.correctionFailures.listen(fails.add);

    bloc.add(const MessagesClearHistoryRequested());
    await tick();

    expect(fails, [const MessagesForbiddenFailure()]);
    await sub.cancel();
    await bloc.close();
  });

  test('error NO tipado → UnknownMessagesFailure', () async {
    when(() => repo.clearHistory(any(), any())).thenThrow(StateError('boom'));
    final bloc = build();
    final fails = <MessagesFailure>[];
    final sub = bloc.correctionFailures.listen(fails.add);

    bloc.add(const MessagesClearHistoryRequested());
    await tick();

    expect(fails, [const UnknownMessagesFailure()]);
    await sub.cancel();
    await bloc.close();
  });
}
