import 'package:ataulfo/features/bots/domain/entities/session_status.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_session_status_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSessionRepo extends Mock implements BotSessionRepository {}

const _connected = SessionStatus(state: SessionState.connected);
const _disconnected = SessionStatus(state: SessionState.disconnected);

void main() {
  late _MockSessionRepo repo;

  setUp(() {
    repo = _MockSessionRepo();
  });

  BotSessionStatusBloc build() => BotSessionStatusBloc(repo: repo, botId: 'b1');

  test('estado inicial es Loading', () {
    final bloc = build();
    addTearDown(bloc.close);
    expect(bloc.state, const BotSessionStatusLoading());
  });

  blocTest<BotSessionStatusBloc, BotSessionStatusState>(
    'Started: GET ok → Loaded(status)',
    build: build,
    setUp: () {
      when(
        () => repo.getSessionState('b1'),
      ).thenAnswer((_) async => _connected);
    },
    act: (bloc) => bloc.add(const BotSessionStatusStarted()),
    expect: () => <BotSessionStatusState>[
      const BotSessionStatusLoaded(_connected),
    ],
  );

  blocTest<BotSessionStatusBloc, BotSessionStatusState>(
    'Started: GET falla → Failed (la página degrada el hero, no rompe)',
    build: build,
    setUp: () {
      when(
        () => repo.getSessionState('b1'),
      ).thenThrow(const BotsForbiddenFailure());
    },
    act: (bloc) => bloc.add(const BotSessionStatusStarted()),
    expect: () => <BotSessionStatusState>[const BotSessionStatusFailed()],
  );

  blocTest<BotSessionStatusBloc, BotSessionStatusState>(
    'Polled desde Loaded: trae el estado fresco',
    build: build,
    setUp: () {
      when(
        () => repo.getSessionState('b1'),
      ).thenAnswer((_) async => _disconnected);
    },
    seed: () => const BotSessionStatusLoaded(_connected),
    act: (bloc) => bloc.add(const BotSessionStatusPolled()),
    expect: () => <BotSessionStatusState>[
      const BotSessionStatusLoaded(_disconnected),
    ],
  );

  blocTest<BotSessionStatusBloc, BotSessionStatusState>(
    'Polled falla desde Loaded: conserva el último estado bueno '
    '(un fallo de red transitorio no falsea una desconexión)',
    build: build,
    setUp: () {
      when(
        () => repo.getSessionState('b1'),
      ).thenThrow(const BotsNetworkFailure());
    },
    seed: () => const BotSessionStatusLoaded(_connected),
    act: (bloc) => bloc.add(const BotSessionStatusPolled()),
    expect: () => <BotSessionStatusState>[],
  );

  blocTest<BotSessionStatusBloc, BotSessionStatusState>(
    'Polled desde Failed: un tick exitoso recupera el hero',
    build: build,
    setUp: () {
      when(
        () => repo.getSessionState('b1'),
      ).thenAnswer((_) async => _connected);
    },
    seed: () => const BotSessionStatusFailed(),
    act: (bloc) => bloc.add(const BotSessionStatusPolled()),
    expect: () => <BotSessionStatusState>[
      const BotSessionStatusLoaded(_connected),
    ],
  );
}
