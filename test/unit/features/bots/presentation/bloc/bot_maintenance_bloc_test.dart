import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_maintenance_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockSessionRepo extends Mock implements BotSessionRepository {}

const _running = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 3,
  paused: false,
  aiDisabled: false,
);

const _paused = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 4,
  paused: true,
  aiDisabled: false,
);

void main() {
  late _MockBotsRepo botsRepo;
  late _MockSessionRepo sessionRepo;

  setUp(() {
    botsRepo = _MockBotsRepo();
    sessionRepo = _MockSessionRepo();
  });

  BotMaintenanceBloc build() => BotMaintenanceBloc(
    botsRepo: botsRepo,
    sessionRepo: sessionRepo,
    botId: 'b1',
  );

  test('estado inicial = Loading', () {
    expect(build().state, const BotMaintenanceLoading());
  });

  group('carga', () {
    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'LoadRequested → Loaded(bot)',
      setUp: () => when(() => botsRepo.byId('b1')).thenAnswer((_) async => _paused),
      build: build,
      act: (b) => b.add(const BotMaintenanceLoadRequested()),
      expect: () => const <BotMaintenanceState>[BotMaintenanceLoaded(_paused)],
    );

    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'LoadRequested NotFound → Failed',
      setUp: () => when(
        () => botsRepo.byId('b1'),
      ).thenThrow(const BotsNotFoundFailure()),
      build: build,
      act: (b) => b.add(const BotMaintenanceLoadRequested()),
      expect: () => const <BotMaintenanceState>[
        BotMaintenanceFailed(BotsNotFoundFailure()),
      ],
    );
  });

  group('pausa (desbloqueo)', () {
    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'PauseToggled desde no-pausado → Busy → Loaded(pausado, version+1)',
      setUp: () => when(
        () => botsRepo.update(id: 'b1', version: 3, paused: true),
      ).thenAnswer((_) async => _paused),
      build: build,
      seed: () => const BotMaintenanceLoaded(_running),
      act: (b) => b.add(const BotMaintenancePauseToggled()),
      expect: () => const <BotMaintenanceState>[
        BotMaintenanceBusy(_running),
        BotMaintenanceLoaded(_paused),
      ],
      verify: (_) =>
          verify(() => botsRepo.update(id: 'b1', version: 3, paused: true)).called(1),
    );
  });

  group('clear/reset (Tier A)', () {
    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'ClearRequested OK → Busy → OpSucceeded(clear) → Loaded',
      setUp: () =>
          when(() => sessionRepo.clearConversations('b1')).thenAnswer((_) async {}),
      build: build,
      seed: () => const BotMaintenanceLoaded(_paused),
      act: (b) => b.add(const BotMaintenanceClearRequested()),
      expect: () => const <BotMaintenanceState>[
        BotMaintenanceBusy(_paused),
        BotMaintenanceOpSucceeded(_paused, MaintenanceOp.clear),
        BotMaintenanceLoaded(_paused),
      ],
      verify: (_) =>
          verify(() => sessionRepo.clearConversations('b1')).called(1),
    );

    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'ClearRequested con bot no pausado → 409 → OpFailed(NotPaused)',
      setUp: () => when(
        () => sessionRepo.clearConversations('b1'),
      ).thenThrow(const BotsNotPausedFailure()),
      build: build,
      seed: () => const BotMaintenanceLoaded(_running),
      act: (b) => b.add(const BotMaintenanceClearRequested()),
      expect: () => const <BotMaintenanceState>[
        BotMaintenanceBusy(_running),
        BotMaintenanceOpFailed(_running, BotsNotPausedFailure()),
      ],
    );

    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'ResetRequested OK → Busy → OpSucceeded(reset) → Loaded',
      setUp: () =>
          when(() => sessionRepo.resetSessions('b1')).thenAnswer((_) async {}),
      build: build,
      seed: () => const BotMaintenanceLoaded(_paused),
      act: (b) => b.add(const BotMaintenanceResetRequested()),
      expect: () => const <BotMaintenanceState>[
        BotMaintenanceBusy(_paused),
        BotMaintenanceOpSucceeded(_paused, MaintenanceOp.reset),
        BotMaintenanceLoaded(_paused),
      ],
    );

    blocTest<BotMaintenanceBloc, BotMaintenanceState>(
      'ClearRequested sin snapshot (Loading) se ignora',
      build: build,
      act: (b) => b.add(const BotMaintenanceClearRequested()),
      expect: () => const <BotMaintenanceState>[],
      verify: (_) => verifyNever(() => sessionRepo.clearConversations(any())),
    );
  });
}
