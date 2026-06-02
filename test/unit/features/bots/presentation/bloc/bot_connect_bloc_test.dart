import 'package:ataulfo/features/bots/domain/entities/connect_link.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_connect_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotSessionRepository {}

final _link = ConnectLink(
  url: 'https://api.ataulfo.app/connect?token=tok',
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
    'Started SOLO emite el enlace; NO arranca la sesión (link async)',
    build: () {
      when(() => repo.issueConnectLink('b1')).thenAnswer((_) async => _link);
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    act: (bloc) => bloc.add(const BotConnectStarted()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) {
      verify(() => repo.issueConnectLink('b1')).called(1);
      // Clave del fix: arrancar la sesión al emitir el enlace cerraría el QR
      // (~2 min) antes de que el tercero abra el enlace. Start es aparte.
      verifyNever(() => repo.startSession(any()));
    },
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'mint falla → [Failed]',
    build: () {
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
    'PairingRequested arranca la sesión → [starting, active]',
    build: () {
      when(() => repo.startSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link),
    act: (bloc) => bloc.add(const BotConnectPairingRequested()),
    expect: () => <BotConnectState>[
      BotConnectReady(_link, phase: PairingPhase.starting),
      BotConnectReady(_link, phase: PairingPhase.active),
    ],
    verify: (_) => verify(() => repo.startSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'PairingRequested con fallo de start → [starting, failed] conservando el enlace',
    build: () {
      when(() => repo.startSession('b1')).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link),
    act: (bloc) => bloc.add(const BotConnectPairingRequested()),
    expect: () => <BotConnectState>[
      BotConnectReady(_link, phase: PairingPhase.starting),
      BotConnectReady(_link, phase: PairingPhase.failed),
    ],
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'retry del mint desde Failed → [Loading, Ready]',
    build: () {
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

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested desde Ready(active) → stopSession invocado → Ready(idle)',
    build: () {
      when(() => repo.stopSession('b1')).thenAnswer((_) async {});
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.stopSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested idempotente: aun si stopSession falla, vuelve a idle',
    build: () {
      when(() => repo.stopSession('b1')).thenThrow(const BotsServerFailure());
      return BotConnectBloc(repo: repo, botId: 'b1');
    },
    seed: () => BotConnectReady(_link, phase: PairingPhase.active),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => <BotConnectState>[BotConnectReady(_link)],
    verify: (_) => verify(() => repo.stopSession('b1')).called(1),
  );

  blocTest<BotConnectBloc, BotConnectState>(
    'StopRequested fuera de Ready se ignora (no llama stopSession)',
    build: () => BotConnectBloc(repo: repo, botId: 'b1'),
    act: (bloc) => bloc.add(const BotConnectStopRequested()),
    expect: () => const <BotConnectState>[],
    verify: (_) => verifyNever(() => repo.stopSession(any())),
  );
}
