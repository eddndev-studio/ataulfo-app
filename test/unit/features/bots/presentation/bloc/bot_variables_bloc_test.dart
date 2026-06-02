import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/entities/bot_variables_snapshot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bot_variables_bloc.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

// El bot está en version 5 y cuelga de la plantilla t1.
const _bot = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: null,
  version: 5,
  paused: false,
  aiDisabled: false,
);

const _defs = <VariableDef>[
  VariableDef(
    id: 'v1',
    name: 'tono',
    defaultValue: 'neutral',
    description: 'Tono de las respuestas',
  ),
  VariableDef(
    id: 'v2',
    name: 'firma',
    defaultValue: 'El equipo',
    description: 'Firma al cierre',
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(<String, String>{});
  });

  late _MockBotsRepo botsRepo;
  late _MockTemplatesRepo templatesRepo;

  setUp(() {
    botsRepo = _MockBotsRepo();
    templatesRepo = _MockTemplatesRepo();
  });

  BotVariablesBloc build() => BotVariablesBloc(
    botsRepo: botsRepo,
    templatesRepo: templatesRepo,
    botId: 'b1',
  );

  test('estado inicial = BotVariablesLoading', () {
    expect(build().state, const BotVariablesLoading());
  });

  // getVariables resuelve {version del BOT, templateId, overrides guardados}
  // en una sola lectura ADMIN+; la version del template (9) NUNCA se filtra.
  const snap = BotVariablesSnapshot(
    version: 5,
    templateId: 't1',
    values: <String, String>{'tono': 'formal'},
  );

  group('carga (MAJOR 2 + precarga de overrides)', () {
    blocTest<BotVariablesBloc, BotVariablesState>(
      'load: getVariables + listVarDefs → Loaded(defs, botVersion=5, '
      'currentValues precargados)',
      setUp: () {
        when(() => botsRepo.getVariables('b1')).thenAnswer((_) async => snap);
        // El template está en version 9 — NO debe filtrarse al PUT.
        when(
          () => templatesRepo.listVarDefs('t1'),
        ).thenAnswer((_) async => (version: 9, defs: _defs));
      },
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[
        BotVariablesLoaded(
          defs: _defs,
          botVersion: 5,
          currentValues: <String, String>{'tono': 'formal'},
        ),
      ],
      verify: (_) {
        verify(() => botsRepo.getVariables('b1')).called(1);
        verify(() => templatesRepo.listVarDefs('t1')).called(1);
        // El bug original leía byId (que no trae overrides). Ya no se usa.
        verifyNever(() => botsRepo.byId(any()));
      },
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'template sin defs → Empty',
      setUp: () {
        when(() => botsRepo.getVariables('b1')).thenAnswer((_) async => snap);
        when(
          () => templatesRepo.listVarDefs('t1'),
        ).thenAnswer((_) async => (version: 9, defs: const <VariableDef>[]));
      },
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[BotVariablesEmpty()],
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'getVariables NotFound → Failed(notFound)',
      setUp: () => when(
        () => botsRepo.getVariables('b1'),
      ).thenThrow(const BotsNotFoundFailure()),
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[
        BotVariablesFailed(BotVariablesLoadError.notFound),
      ],
      verify: (_) => verifyNever(() => templatesRepo.listVarDefs(any())),
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'listVarDefs Forbidden → Failed(forbidden)',
      setUp: () {
        when(() => botsRepo.getVariables('b1')).thenAnswer((_) async => snap);
        when(
          () => templatesRepo.listVarDefs('t1'),
        ).thenThrow(const TemplatesForbiddenFailure());
      },
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[
        BotVariablesFailed(BotVariablesLoadError.forbidden),
      ],
    );
  });

  group('guardar (replace WRITE-ONLY)', () {
    blocTest<BotVariablesBloc, BotVariablesState>(
      'SaveRequested envía PUT con bot.version (5), NUNCA la del template (9)',
      setUp: () => when(
        () => botsRepo.update(
          id: 'b1',
          version: 5,
          variableValues: <String, String>{'tono': 'formal'},
        ),
      ).thenAnswer((_) async => _bot),
      build: build,
      seed: () => const BotVariablesLoaded(defs: _defs, botVersion: 5),
      act: (b) => b.add(
        const BotVariablesSaveRequested(<String, String>{'tono': 'formal'}),
      ),
      expect: () => const <BotVariablesState>[
        BotVariablesSaving(defs: _defs, botVersion: 5),
        BotVariablesSaved(),
      ],
      verify: (_) => verify(
        () => botsRepo.update(
          id: 'b1',
          version: 5,
          variableValues: <String, String>{'tono': 'formal'},
        ),
      ).called(1),
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'vaciar overrides envía {} (mapa vacío), jamás null',
      setUp: () => when(
        () => botsRepo.update(
          id: any(named: 'id'),
          version: any(named: 'version'),
          variableValues: any(named: 'variableValues'),
        ),
      ).thenAnswer((_) async => _bot),
      build: build,
      seed: () => const BotVariablesLoaded(defs: _defs, botVersion: 5),
      act: (b) => b.add(const BotVariablesSaveRequested(<String, String>{})),
      expect: () => const <BotVariablesState>[
        BotVariablesSaving(defs: _defs, botVersion: 5),
        BotVariablesSaved(),
      ],
      verify: (_) => verify(
        () => botsRepo.update(
          id: 'b1',
          version: 5,
          variableValues: <String, String>{},
        ),
      ).called(1),
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'save 409 → SaveFailed(conflict) conservando defs+version',
      setUp: () => when(
        () => botsRepo.update(
          id: any(named: 'id'),
          version: any(named: 'version'),
          variableValues: any(named: 'variableValues'),
        ),
      ).thenThrow(const BotsConflictFailure()),
      build: build,
      seed: () => const BotVariablesLoaded(defs: _defs, botVersion: 5),
      act: (b) =>
          b.add(const BotVariablesSaveRequested(<String, String>{'tono': 'x'})),
      expect: () => const <BotVariablesState>[
        BotVariablesSaving(defs: _defs, botVersion: 5),
        BotVariablesSaveFailed(
          defs: _defs,
          botVersion: 5,
          failure: BotsConflictFailure(),
        ),
      ],
    );
  });
}
