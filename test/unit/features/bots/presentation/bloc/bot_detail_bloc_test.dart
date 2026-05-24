import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/failures/bots_failure.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/bots/presentation/bloc/bot_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements BotsRepository {}

const _b1 = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('BotDetailBloc', () {
    test('estado inicial = BotDetailLoading', () {
      // Pattern: el bloc se construye con el ID y arranca en Loading. La
      // página dispara LoadRequested vía el provider y la UI ya tiene un
      // spinner desde el primer frame — no hay flash de Initial.
      final bloc = BotDetailBloc(repo: repo, id: 'b1');
      expect(bloc.state, const BotDetailLoading());
    });

    blocTest<BotDetailBloc, BotDetailState>(
      'LoadRequested + repo.byId OK → Loaded(bot)',
      build: () {
        when(() => repo.byId('b1')).thenAnswer((_) async => _b1);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      act: (bloc) => bloc.add(const BotDetailLoadRequested()),
      // Loading inicial vs Loading emitido por el handler colapsan por
      // value-eq; sólo Loaded entra en la lista de emisiones.
      expect: () => const <BotDetailState>[BotDetailLoaded(_b1)],
      verify: (_) => verify(() => repo.byId('b1')).called(1),
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'LoadRequested + repo.byId NotFound → Failed(NotFound)',
      build: () {
        when(
          () => repo.byId('missing'),
        ).thenAnswer((_) => Future<Bot>.error(const BotsNotFoundFailure()));
        return BotDetailBloc(repo: repo, id: 'missing');
      },
      act: (bloc) => bloc.add(const BotDetailLoadRequested()),
      expect: () => const <BotDetailState>[
        BotDetailFailed(BotsNotFoundFailure()),
      ],
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'retry desde Failed: LoadRequested re-emite Loading y luego Loaded',
      build: () {
        when(() => repo.byId('b1')).thenAnswer((_) async => _b1);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      // El usuario llega al estado Failed y toca "Reintentar". Aquí
      // forzamos ese seed; el handler debe pasar por Loading visible (no
      // colapsa porque Failed ≠ Loading) antes de aterrizar en Loaded.
      seed: () => const BotDetailFailed(BotsNetworkFailure()),
      act: (bloc) => bloc.add(const BotDetailLoadRequested()),
      expect: () => const <BotDetailState>[
        BotDetailLoading(),
        BotDetailLoaded(_b1),
      ],
    );

    test('value-equality de eventos y estados', () {
      expect(const BotDetailLoadRequested(), const BotDetailLoadRequested());
      expect(const BotDetailLoading(), const BotDetailLoading());
      expect(const BotDetailLoaded(_b1), const BotDetailLoaded(_b1));
      expect(
        const BotDetailFailed(BotsServerFailure()),
        const BotDetailFailed(BotsServerFailure()),
      );
      expect(
        const BotDetailFailed(BotsServerFailure()) ==
            const BotDetailFailed(BotsNetworkFailure()),
        isFalse,
      );
    });
  });
}
