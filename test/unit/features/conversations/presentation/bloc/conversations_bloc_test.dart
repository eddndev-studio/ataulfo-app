import 'dart:async';

import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ConversationsRepository {}

const _c1 = Conversation(
  chatLid: 'lid-1',
  kind: ConversationKind.dm,
  phone: '5215550001',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);
const _c2 = Conversation(
  chatLid: 'lid-2',
  kind: ConversationKind.group,
  phone: null,
  isArchived: false,
  isPinned: true,
  isMarkedUnread: false,
  mutedUntil: null,
);

/// Cede el loop para drenar microtasks (eventos del bloc + futures de refresh).
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late _MockRepo repo;
  late StreamController<List<Conversation>> watch;

  setUp(() {
    repo = _MockRepo();
    watch = StreamController<List<Conversation>>.broadcast();
    when(() => repo.watchForBot('b1')).thenAnswer((_) => watch.stream);
  });

  tearDown(() => watch.close());

  ConversationsBloc build() => ConversationsBloc(repo: repo, botId: 'b1');

  test('estado inicial = ConversationsInitial', () {
    expect(build().state, const ConversationsInitial());
  });

  test(
    'load: Loading, dispara refresh, y la emisión del watch → Loaded',
    () async {
      when(() => repo.refresh('b1')).thenAnswer((_) async {});
      final bloc = build();
      final states = <ConversationsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const ConversationsLoadRequested());
      await tick(); // Load -> Loading + suscribe + refresh (ok, sin items aún)
      watch.add(const <Conversation>[_c1, _c2]); // write-through del refresh
      await tick();

      expect(states, const <ConversationsState>[
        ConversationsLoading(),
        ConversationsLoaded(
          items: <Conversation>[_c1, _c2],
          isRefreshing: false,
        ),
      ]);
      verify(() => repo.refresh('b1')).called(1);

      await sub.cancel();
      await bloc.close();
    },
  );

  test('load con bandeja vacía → Loaded([])', () async {
    when(() => repo.refresh('b1')).thenAnswer((_) async {});
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick();
    watch.add(const <Conversation>[]);
    await tick();

    expect(
      states.last,
      const ConversationsLoaded(items: [], isRefreshing: false),
    );
    await sub.cancel();
    await bloc.close();
  });

  test('refresh falla sin caché → Failed', () async {
    final done = Completer<void>();
    when(() => repo.refresh('b1')).thenAnswer((_) => done.future);
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick(); // Loading; refresh en curso; sin emisión del watch (sin caché)
    done.completeError(const ConversationsNetworkFailure());
    await tick();

    expect(states, const <ConversationsState>[
      ConversationsLoading(),
      ConversationsFailed(ConversationsNetworkFailure()),
    ]);
    await sub.cancel();
    await bloc.close();
  });

  test('refresh falla CON caché → sirve la caché (no Failed)', () async {
    final done = Completer<void>();
    when(() => repo.refresh('b1')).thenAnswer((_) => done.future);
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick(); // Loading; refresh en curso (isRefreshing=true)
    watch.add(const <Conversation>[_c1]); // caché local
    await tick(); // Loaded([_c1], true)
    done.completeError(const ConversationsNetworkFailure());
    await tick(); // catch: con caché no degrada → Loaded([_c1], false)

    expect(
      states.last,
      const ConversationsLoaded(items: [_c1], isRefreshing: false),
    );
    expect(states.whereType<ConversationsFailed>(), isEmpty);
    await sub.cancel();
    await bloc.close();
  });

  test('error del watch sin caché → Failed', () async {
    when(() => repo.refresh('b1')).thenAnswer((_) async {});
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick();
    watch.addError(const ConversationsNetworkFailure());
    await tick();

    expect(
      states.last,
      const ConversationsFailed(ConversationsNetworkFailure()),
    );
    await sub.cancel();
    await bloc.close();
  });

  test('error del watch CON caché → mantiene la caché (no Failed)', () async {
    when(() => repo.refresh('b1')).thenAnswer((_) async {});
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick();
    watch.add(const <Conversation>[_c1]);
    await tick();
    watch.addError(const ConversationsNetworkFailure());
    await tick();

    expect(states.whereType<ConversationsFailed>(), isEmpty);
    expect(
      states.last,
      const ConversationsLoaded(items: [_c1], isRefreshing: false),
    );
    await sub.cancel();
    await bloc.close();
  });

  test('emisiones posteriores del watch actualizan la lista', () async {
    when(() => repo.refresh('b1')).thenAnswer((_) async {});
    final bloc = build();
    final states = <ConversationsState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const ConversationsLoadRequested());
    await tick();
    watch.add(const <Conversation>[_c1]);
    await tick();
    watch.add(const <Conversation>[_c1, _c2]); // p. ej. realtime/refresh futuro
    await tick();

    expect(
      states.last,
      const ConversationsLoaded(items: [_c1, _c2], isRefreshing: false),
    );
    await sub.cancel();
    await bloc.close();
  });
}
