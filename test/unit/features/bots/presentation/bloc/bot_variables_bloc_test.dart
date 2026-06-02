import 'package:ataulfo/features/bots/domain/entities/bot.dart';
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
    type: VarType.text,
    defaultValue: 'neutral',
    description: 'Tono de las respuestas',
  ),
  VariableDef(
    id: 'v2',
    name: 'firma',
    type: VarType.text,
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

  group('carga (MAJOR 2: versión del BOT, no del template)', () {
    blocTest<BotVariablesBloc, BotVariablesState>(
      'load: byId + listVarDefs(bot.templateId) → Loaded(defs, botVersion=5)',
      setUp: () {
        when(() => botsRepo.byId('b1')).thenAnswer((_) async => _bot);
        // El template está en version 9 — NO debe filtrarse al PUT.
        when(() => templatesRepo.listVarDefs('t1')).thenAnswer(
          (_) async => (version: 9, defs: _defs),
        );
      },
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[
        BotVariablesLoaded(defs: _defs, botVersion: 5),
      ],
      verify: (_) {
        verify(() => botsRepo.byId('b1')).called(1);
        verify(() => templatesRepo.listVarDefs('t1')).called(1);
      },
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'template sin defs → Empty',
      setUp: () {
        when(() => botsRepo.byId('b1')).thenAnswer((_) async => _bot);
        when(() => templatesRepo.listVarDefs('t1')).thenAnswer(
          (_) async => (version: 9, defs: const <VariableDef>[]),
        );
      },
      build: build,
      act: (b) => b.add(const BotVariablesLoadRequested()),
      expect: () => const <BotVariablesState>[BotVariablesEmpty()],
    );

    blocTest<BotVariablesBloc, BotVariablesState>(
      'byId NotFound → Failed(notFound)',
      setUp: () => when(
        () => botsRepo.byId('b1'),
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
        when(() => botsRepo.byId('b1')).thenAnswer((_) async => _bot);
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
      act: (b) =>
          b.add(const BotVariablesSaveRequested(<String, String>{})),
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
      act: (b) => b.add(
        const BotVariablesSaveRequested(<String, String>{'tono': 'x'}),
      ),
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
