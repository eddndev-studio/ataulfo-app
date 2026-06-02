import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_detail_bloc.dart';
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

// Resultado del PUT que invierte `paused`: el backend devuelve version+1.
const _b1Paused = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 4,
  paused: true,
  aiDisabled: false,
);

// Snapshot fresco que devuelve el re-GET tras un 409: otra edición ganó la
// carrera (version saltó a 6).
const _b1Fresh = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte (renombrado por otro)',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 6,
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
      // Estados/eventos nuevos de mutación.
      expect(const BotDetailMutating(_b1), const BotDetailMutating(_b1));
      expect(
        const BotDetailMutationFailed(_b1, BotsConflictFailure()),
        const BotDetailMutationFailed(_b1, BotsConflictFailure()),
      );
      expect(
        const BotDetailMutationFailed(_b1, BotsConflictFailure()) ==
            const BotDetailMutationFailed(_b1Fresh, BotsConflictFailure()),
        isFalse,
      );
      expect(
        const BotDetailUpdateRequested(paused: true),
        const BotDetailUpdateRequested(paused: true),
      );
      expect(
        const BotDetailUpdateRequested(paused: true) ==
            const BotDetailUpdateRequested(name: 'x'),
        isFalse,
      );
    });
  });

  group('BotDetailBloc — mutación (CRUD graduado)', () {
    blocTest<BotDetailBloc, BotDetailState>(
      'UpdateRequested(paused) OK → Mutating(snapshot) → Loaded(version+1)',
      build: () {
        when(
          () => repo.update(
            id: 'b1',
            version: 3,
            name: null,
            paused: true,
            aiDisabled: null,
            variableValues: null,
          ),
        ).thenAnswer((_) async => _b1Paused);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailUpdateRequested(paused: true)),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailLoaded(_b1Paused),
      ],
      verify: (_) => verify(
        () => repo.update(
          id: 'b1',
          version: 3,
          name: null,
          paused: true,
          aiDisabled: null,
          variableValues: null,
        ),
      ).called(1),
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'UpdateRequested 409 → Mutating → MutationFailed(fresh, conflict) [re-GET]',
      build: () {
        when(
          () => repo.update(
            id: any(named: 'id'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            paused: any(named: 'paused'),
            aiDisabled: any(named: 'aiDisabled'),
            variableValues: any(named: 'variableValues'),
          ),
        ).thenAnswer((_) => Future<Bot>.error(const BotsConflictFailure()));
        // El re-GET trae la versión fresca: el reintento usará la versión
        // correcta y el copy de conflicto sigue visible.
        when(() => repo.byId('b1')).thenAnswer((_) async => _b1Fresh);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailUpdateRequested(name: 'Soporte+')),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailMutationFailed(_b1Fresh, BotsConflictFailure()),
      ],
      verify: (_) => verify(() => repo.byId('b1')).called(1),
    );

    blocTest<BotDetailBloc, BotDetailState>(
      '409 con re-GET fallido → MutationFailed(snapshot, conflict)',
      build: () {
        when(
          () => repo.update(
            id: any(named: 'id'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            paused: any(named: 'paused'),
            aiDisabled: any(named: 'aiDisabled'),
            variableValues: any(named: 'variableValues'),
          ),
        ).thenAnswer((_) => Future<Bot>.error(const BotsConflictFailure()));
        when(
          () => repo.byId('b1'),
        ).thenAnswer((_) => Future<Bot>.error(const BotsNetworkFailure()));
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailUpdateRequested(name: 'x')),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailMutationFailed(_b1, BotsConflictFailure()),
      ],
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'UpdateRequested con otra failure → MutationFailed(snapshot, failure)',
      build: () {
        when(
          () => repo.update(
            id: any(named: 'id'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            paused: any(named: 'paused'),
            aiDisabled: any(named: 'aiDisabled'),
            variableValues: any(named: 'variableValues'),
          ),
        ).thenAnswer((_) => Future<Bot>.error(const BotsServerFailure()));
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailUpdateRequested(aiDisabled: true)),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailMutationFailed(_b1, BotsServerFailure()),
      ],
      verify: (_) => verifyNever(() => repo.byId(any())),
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'nueva mutación desde MutationFailed reusa el snapshot (fresco)',
      build: () {
        when(
          () => repo.update(
            id: 'b1',
            version: 6,
            name: null,
            paused: true,
            aiDisabled: null,
            variableValues: null,
          ),
        ).thenAnswer((_) async => _b1Paused);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () =>
          const BotDetailMutationFailed(_b1Fresh, BotsConflictFailure()),
      act: (b) => b.add(const BotDetailUpdateRequested(paused: true)),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1Fresh),
        BotDetailLoaded(_b1Paused),
      ],
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'UpdateRequested sin snapshot (Loading) se ignora',
      build: () => BotDetailBloc(repo: repo, id: 'b1'),
      act: (b) => b.add(const BotDetailUpdateRequested(paused: true)),
      expect: () => const <BotDetailState>[],
      verify: (_) => verifyNever(
        () => repo.update(
          id: any(named: 'id'),
          version: any(named: 'version'),
          name: any(named: 'name'),
          paused: any(named: 'paused'),
          aiDisabled: any(named: 'aiDisabled'),
          variableValues: any(named: 'variableValues'),
        ),
      ),
    );
  });

  group('BotDetailBloc — clonar (éxito = navegación)', () {
    const clone = Bot(
      id: 'b2',
      orgId: 'o1',
      templateId: 't1',
      name: 'Soporte (copia)',
      channel: BotChannel.waUnofficial,
      identifier: null,
      version: 0,
      paused: false,
      aiDisabled: false,
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'CloneRequested OK → Mutating → CloneSucceeded(newId) → Loaded(snapshot)',
      build: () {
        when(
          () => repo.clone(id: 'b1', name: 'Soporte (copia)'),
        ).thenAnswer((_) async => clone);
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailCloneRequested('Soporte (copia)')),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailCloneSucceeded('b2'),
        BotDetailLoaded(_b1), // snapshot intacto: el clon es OTRO bot
      ],
      verify: (_) =>
          verify(() => repo.clone(id: 'b1', name: 'Soporte (copia)')).called(1),
    );

    blocTest<BotDetailBloc, BotDetailState>(
      'CloneRequested 422 → Mutating → MutationFailed(snapshot, invalid)',
      build: () {
        when(
          () => repo.clone(
            id: any(named: 'id'),
            name: any(named: 'name'),
          ),
        ).thenAnswer(
          (_) => Future<Bot>.error(const BotsInvalidCreateFailure()),
        );
        return BotDetailBloc(repo: repo, id: 'b1');
      },
      seed: () => const BotDetailLoaded(_b1),
      act: (b) => b.add(const BotDetailCloneRequested('')),
      expect: () => const <BotDetailState>[
        BotDetailMutating(_b1),
        BotDetailMutationFailed(_b1, BotsInvalidCreateFailure()),
      ],
    );

    test('value-equality del evento y el estado de clone', () {
      expect(
        const BotDetailCloneRequested('x'),
        const BotDetailCloneRequested('x'),
      );
      expect(
        const BotDetailCloneRequested('x') ==
            const BotDetailCloneRequested('y'),
        isFalse,
      );
      expect(
        const BotDetailCloneSucceeded('b2'),
        const BotDetailCloneSucceeded('b2'),
      );
      expect(
        const BotDetailCloneSucceeded('b2') ==
            const BotDetailCloneSucceeded('b3'),
        isFalse,
      );
    });
  });
}
