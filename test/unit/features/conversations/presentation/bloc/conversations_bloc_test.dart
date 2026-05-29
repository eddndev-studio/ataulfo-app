import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
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

void main() {
  ConversationsBloc build(_MockRepo repo) =>
      ConversationsBloc(repo: repo, botId: 'b1');

  group('ConversationsBloc', () {
    test('estado inicial = ConversationsInitial', () {
      expect(build(_MockRepo()).state, const ConversationsInitial());
    });

    group('ConversationsLoadRequested', () {
      blocTest<ConversationsBloc, ConversationsState>(
        'ok → [Loading, Loaded(items, false)] y pide listForBot(botId)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listForBot('b1'),
          ).thenAnswer((_) async => const <Conversation>[_c1, _c2]);
          return build(repo);
        },
        act: (b) => b.add(const ConversationsLoadRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoading(),
          ConversationsLoaded(
            items: <Conversation>[_c1, _c2],
            isRefreshing: false,
          ),
        ],
        verify: (_) {},
      );

      blocTest<ConversationsBloc, ConversationsState>(
        'ok [] → [Loading, Loaded(empty)]',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listForBot('b1'),
          ).thenAnswer((_) async => const <Conversation>[]);
          return build(repo);
        },
        act: (b) => b.add(const ConversationsLoadRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoading(),
          ConversationsLoaded(items: <Conversation>[], isRefreshing: false),
        ],
      );

      blocTest<ConversationsBloc, ConversationsState>(
        '404 → [Loading, Failed(NotFound)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.listForBot('b1')).thenAnswer(
            (_) => Future<List<Conversation>>.error(
              const ConversationsNotFoundFailure(),
            ),
          );
          return build(repo);
        },
        act: (b) => b.add(const ConversationsLoadRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoading(),
          ConversationsFailed(ConversationsNotFoundFailure()),
        ],
      );

      blocTest<ConversationsBloc, ConversationsState>(
        'network → [Loading, Failed(Network)]',
        build: () {
          final repo = _MockRepo();
          when(() => repo.listForBot('b1')).thenAnswer(
            (_) => Future<List<Conversation>>.error(
              const ConversationsNetworkFailure(),
            ),
          );
          return build(repo);
        },
        act: (b) => b.add(const ConversationsLoadRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoading(),
          ConversationsFailed(ConversationsNetworkFailure()),
        ],
      );
    });

    group('ConversationsRefreshRequested', () {
      blocTest<ConversationsBloc, ConversationsState>(
        'desde Loaded → Loaded(prev, true) y luego Loaded(nuevos, false)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listForBot('b1'),
          ).thenAnswer((_) async => const <Conversation>[_c2]);
          return build(repo);
        },
        seed: () => const ConversationsLoaded(
          items: <Conversation>[_c1],
          isRefreshing: false,
        ),
        act: (b) => b.add(const ConversationsRefreshRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoaded(items: <Conversation>[_c1], isRefreshing: true),
          ConversationsLoaded(items: <Conversation>[_c2], isRefreshing: false),
        ],
      );

      blocTest<ConversationsBloc, ConversationsState>(
        'desde Loaded con error → mantiene visible la lista y emite Failed',
        build: () {
          final repo = _MockRepo();
          when(() => repo.listForBot('b1')).thenAnswer(
            (_) => Future<List<Conversation>>.error(
              const ConversationsNetworkFailure(),
            ),
          );
          return build(repo);
        },
        seed: () => const ConversationsLoaded(
          items: <Conversation>[_c1],
          isRefreshing: false,
        ),
        act: (b) => b.add(const ConversationsRefreshRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoaded(items: <Conversation>[_c1], isRefreshing: true),
          ConversationsFailed(ConversationsNetworkFailure()),
        ],
      );

      blocTest<ConversationsBloc, ConversationsState>(
        'desde Initial cae a load (no hay prev que refrescar)',
        build: () {
          final repo = _MockRepo();
          when(
            () => repo.listForBot('b1'),
          ).thenAnswer((_) async => const <Conversation>[_c1]);
          return build(repo);
        },
        act: (b) => b.add(const ConversationsRefreshRequested()),
        expect: () => const <ConversationsState>[
          ConversationsLoading(),
          ConversationsLoaded(items: <Conversation>[_c1], isRefreshing: false),
        ],
      );
    });
  });
}
