import 'package:agentic/features/bots/domain/entities/connect_link.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_connect_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotSessionRepository {}

final _link = ConnectLink(
  url: 'https://api.w-gateway.cc/connect?token=tok',
  expiresAt: DateTime.utc(2026, 5, 29, 12, 30, 0),
);

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  test('estado inicial = BotConnectLoading', () {
    final bloc = BotConnectBloc(repo: repo, botId: 'b1');
    expect(bloc.state, const BotConnectLoading());
    bloc.close();
  });

  blocTest<BotConnectBloc, BotConnectState>(
    'Started ok → [Ready(link)] (no re-emite Loading desde el inicial)',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) {
      verifyInOrder(<void Function()>[
        () => repo.startSession('b1'),
        () => repo.issueConnectLink('b1'),
      ]);
    },
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'startSession falla → [Failed]; no emite el token',
    build: () {
      when(
        () => repo.startSession('b1'),
      ).thenThrow(const BotsForbiddenFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => const <BotConnectState>[
      BotConnectFailed(BotsForbiddenFailure()),
    ],
    verify: (_) {
      verifyNever(() => repo.issueConnectLink(any()));
    },
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'issueConnectLink falla → [Failed]',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      when(
        () => repo.issueConnectLink('b1'),
      ).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => const <BotConnectState>[
      BotConnectFailed(BotsServerFailure()),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'retry desde Failed → [Loading, Ready]',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => const BotConnectFailed(BotsServerFailure()),
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => <BotConnectState>[
      const BotConnectLoading(),
      BotConnectReady(_link),
    ],
  );
}
