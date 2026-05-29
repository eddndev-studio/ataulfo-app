import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/message_page.dart';
import 'package:ataulfo/features/messages/domain/failures/messages_failure.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/messages/presentation/bloc/messages_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessagesRepository {}

Message msg(String ext, int ts) => Message(
  externalId: ext,
  chatLid: 'lid-1',
  senderLid: 'a',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'c',
  mediaRef: null,
  quotedId: null,
  timestampMs: ts,
  status: null,
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  MessagesBloc build() =>
      MessagesBloc(repo: repo, botId: 'b1', chatLid: 'lid-1');

  group('Load (cola)', () {
    blocTest<MessagesBloc, MessagesState>(
      'éxito → [Loading, Loaded] con prevCursor',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[msg('m4', 400), msg('m5', 500)],
            prevCursor: '300:m3',
          ),
        );
        return build();
      },
      act: (b) => b.add(const MessagesLoadRequested()),
      expect: () => <MessagesState>[
        const MessagesLoading(),
        MessagesLoaded(
          items: <Message>[msg('m4', 400), msg('m5', 500)],
          prevCursor: '300:m3',
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'failure → [Loading, Failed]',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const MessagesServerFailure());
        return build();
      },
      act: (b) => b.add(const MessagesLoadRequested()),
      expect: () => <MessagesState>[
        const MessagesLoading(),
        const MessagesFailed(MessagesServerFailure()),
      ],
    );
  });

  group('LoadOlder', () {
    blocTest<MessagesBloc, MessagesState>(
      'prepende el tramo más viejo (ASC) + actualiza prevCursor',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: '300:m3',
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => MessagePage(
            messages: <Message>[msg('m2', 200), msg('m3', 300)],
            prevCursor: null,
          ),
        );
        return build();
      },
      seed: () => MessagesLoaded(
        items: <Message>[msg('m4', 400), msg('m5', 500)],
        prevCursor: '300:m3',
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[msg('m4', 400), msg('m5', 500)],
          prevCursor: '300:m3',
          isLoadingOlder: true,
        ),
        MessagesLoaded(
          items: <Message>[
            msg('m2', 200),
            msg('m3', 300),
            msg('m4', 400),
            msg('m5', 500),
          ],
          prevCursor: null,
          isLoadingOlder: false,
        ),
      ],
    );

    blocTest<MessagesBloc, MessagesState>(
      'sin prevCursor (inicio del hilo) → no-op',
      build: build,
      seed: () => MessagesLoaded(
        items: <Message>[msg('m1', 100)],
        prevCursor: null,
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => const <MessagesState>[],
    );

    blocTest<MessagesBloc, MessagesState>(
      'falla el tramo viejo → revierte isLoadingOlder y conserva el hilo',
      build: () {
        when(
          () => repo.thread(
            'b1',
            'lid-1',
            cursor: '300:m3',
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const MessagesNetworkFailure());
        return build();
      },
      seed: () => MessagesLoaded(
        items: <Message>[msg('m4', 400)],
        prevCursor: '300:m3',
        isLoadingOlder: false,
      ),
      act: (b) => b.add(const MessagesOlderRequested()),
      expect: () => <MessagesState>[
        MessagesLoaded(
          items: <Message>[msg('m4', 400)],
          prevCursor: '300:m3',
          isLoadingOlder: true,
        ),
        MessagesLoaded(
          items: <Message>[msg('m4', 400)],
          prevCursor: '300:m3',
          isLoadingOlder: false,
        ),
      ],
    );
  });
}
