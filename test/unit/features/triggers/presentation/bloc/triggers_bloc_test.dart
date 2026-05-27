import 'package:agentic/features/triggers/domain/entities/trigger.dart';
import 'package:agentic/features/triggers/domain/failures/triggers_failure.dart';
import 'package:agentic/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:agentic/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TriggersRepository {}

Trigger _text({String id = 't1', String keyword = 'menu'}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: 'f1',
  triggerType: TriggerType.text,
  matchType: MatchType.exact,
  keyword: keyword,
  labelId: '',
  labelAction: null,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

Trigger _label({String id = 't2', String labelId = 'vip'}) => Trigger(
  id: id,
  templateId: 'tpl1',
  flowId: 'f1',
  triggerType: TriggerType.label,
  matchType: null,
  keyword: '',
  labelId: labelId,
  labelAction: LabelAction.add,
  scope: TriggerScope.both,
  isActive: true,
  createdAt: DateTime.utc(2026, 5, 1),
  updatedAt: DateTime.utc(2026, 5, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(TriggerType.text);
    registerFallbackValue(MatchType.exact);
    registerFallbackValue(LabelAction.add);
    registerFallbackValue(TriggerScope.both);
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('TriggersBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = TriggersBloc(repo: repo, templateId: 'tpl1');
      expect(bloc.state, const TriggersLoading());
      bloc.close();
    });

    blocTest<TriggersBloc, TriggersState>(
      'LoadRequested ok → Loaded(triggers)',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => <Trigger>[_text(), _label()]);
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      act: (bloc) => bloc.add(const TriggersLoadRequested()),
      expect: () => <TriggersState>[
        TriggersLoaded(<Trigger>[_text(), _label()]),
      ],
      verify: (_) => verify(() => repo.listTriggers('tpl1')).called(1),
    );

    blocTest<TriggersBloc, TriggersState>(
      'LoadRequested ok con lista vacía → Loaded([])',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => const <Trigger>[]);
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      act: (bloc) => bloc.add(const TriggersLoadRequested()),
      expect: () => const <TriggersState>[TriggersLoaded(<Trigger>[])],
    );

    blocTest<TriggersBloc, TriggersState>(
      'LoadRequested 404 → Failed(NotFound)',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenThrow(const TriggersNotFoundFailure());
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      act: (bloc) => bloc.add(const TriggersLoadRequested()),
      expect: () => const <TriggersState>[
        TriggersFailed(TriggersNotFoundFailure()),
      ],
    );

    blocTest<TriggersBloc, TriggersState>(
      'LoadRequested network → Failed(Network) y retry vuelve a pasar',
      build: () {
        var calls = 0;
        when(() => repo.listTriggers('tpl1')).thenAnswer((_) async {
          calls += 1;
          if (calls == 1) throw const TriggersNetworkFailure();
          return <Trigger>[_text()];
        });
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      act: (bloc) async {
        bloc.add(const TriggersLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TriggersLoadRequested());
      },
      expect: () => <TriggersState>[
        const TriggersFailed(TriggersNetworkFailure()),
        const TriggersLoading(),
        TriggersLoaded(<Trigger>[_text()]),
      ],
    );

    blocTest<TriggersBloc, TriggersState>(
      'AddRequested ok → Mutating(snap) → Loading → Loaded(refrescada)',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => <Trigger>[_text()]);
        when(
          () => repo.createTrigger(
            templateId: any(named: 'templateId'),
            flowId: any(named: 'flowId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        ).thenAnswer((_) async => _text(id: 'new', keyword: 'nuevo'));
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersLoaded(<Trigger>[_text()]),
      act: (bloc) => bloc.add(
        const TriggersAddRequested(
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'nuevo',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text()]),
        const TriggersLoading(),
        TriggersLoaded(<Trigger>[_text()]),
      ],
      verify: (_) => verify(
        () => repo.createTrigger(
          templateId: 'tpl1',
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'nuevo',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ).called(1),
    );

    blocTest<TriggersBloc, TriggersState>(
      'AddRequested 422 → MutationFailed(snap, Invalid) — lista se preserva',
      build: () {
        when(
          () => repo.createTrigger(
            templateId: any(named: 'templateId'),
            flowId: any(named: 'flowId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        ).thenThrow(const TriggersInvalidFailure());
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersLoaded(<Trigger>[_text()]),
      act: (bloc) => bloc.add(
        const TriggersAddRequested(
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: '',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text()]),
        TriggersMutationFailed(<Trigger>[
          _text(),
        ], const TriggersInvalidFailure()),
      ],
    );

    blocTest<TriggersBloc, TriggersState>(
      'UpdateRequested ok → Mutating → Loading → Loaded(refrescada)',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => <Trigger>[_text(keyword: 'editado')]);
        when(
          () => repo.updateTrigger(
            triggerId: any(named: 'triggerId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        ).thenAnswer((_) async => _text(keyword: 'editado'));
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersLoaded(<Trigger>[_text()]),
      act: (bloc) => bloc.add(
        const TriggersUpdateRequested(
          triggerId: 't1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'editado',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text()]),
        const TriggersLoading(),
        TriggersLoaded(<Trigger>[_text(keyword: 'editado')]),
      ],
    );

    blocTest<TriggersBloc, TriggersState>(
      'UpdateRequested 404 → MutationFailed(snap, NotFound)',
      build: () {
        when(
          () => repo.updateTrigger(
            triggerId: any(named: 'triggerId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        ).thenThrow(const TriggersNotFoundFailure());
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersLoaded(<Trigger>[_text()]),
      act: (bloc) => bloc.add(
        const TriggersUpdateRequested(
          triggerId: 't1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'x',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text()]),
        TriggersMutationFailed(<Trigger>[
          _text(),
        ], const TriggersNotFoundFailure()),
      ],
    );

    blocTest<TriggersBloc, TriggersState>(
      'DeleteRequested ok → Mutating → Loading → Loaded(sin el item)',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => <Trigger>[_label()]);
        when(() => repo.deleteTrigger('t1')).thenAnswer((_) async {});
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersLoaded(<Trigger>[_text(), _label()]),
      act: (bloc) => bloc.add(const TriggersDeleteRequested(triggerId: 't1')),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text(), _label()]),
        const TriggersLoading(),
        TriggersLoaded(<Trigger>[_label()]),
      ],
      verify: (_) => verify(() => repo.deleteTrigger('t1')).called(1),
    );

    blocTest<TriggersBloc, TriggersState>(
      'AddRequested desde Loading se ignora silenciosamente',
      build: () => TriggersBloc(repo: repo, templateId: 'tpl1'),
      // Estado inicial = Loading; no seed.
      act: (bloc) => bloc.add(
        const TriggersAddRequested(
          flowId: 'f1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'x',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => const <TriggersState>[],
      verify: (_) {
        verifyNever(
          () => repo.createTrigger(
            templateId: any(named: 'templateId'),
            flowId: any(named: 'flowId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        );
      },
    );

    blocTest<TriggersBloc, TriggersState>(
      'UpdateRequested desde MutationFailed reusa el snapshot ahí guardado',
      build: () {
        when(
          () => repo.listTriggers('tpl1'),
        ).thenAnswer((_) async => <Trigger>[_text(keyword: 'reintento')]);
        when(
          () => repo.updateTrigger(
            triggerId: any(named: 'triggerId'),
            triggerType: any(named: 'triggerType'),
            matchType: any(named: 'matchType'),
            keyword: any(named: 'keyword'),
            labelId: any(named: 'labelId'),
            labelAction: any(named: 'labelAction'),
            scope: any(named: 'scope'),
            isActive: any(named: 'isActive'),
          ),
        ).thenAnswer((_) async => _text(keyword: 'reintento'));
        return TriggersBloc(repo: repo, templateId: 'tpl1');
      },
      seed: () => TriggersMutationFailed(<Trigger>[
        _text(),
      ], const TriggersInvalidFailure()),
      act: (bloc) => bloc.add(
        const TriggersUpdateRequested(
          triggerId: 't1',
          triggerType: TriggerType.text,
          matchType: MatchType.exact,
          keyword: 'reintento',
          labelId: '',
          labelAction: null,
          scope: TriggerScope.both,
          isActive: true,
        ),
      ),
      expect: () => <TriggersState>[
        TriggersMutating(<Trigger>[_text()]),
        const TriggersLoading(),
        TriggersLoaded(<Trigger>[_text(keyword: 'reintento')]),
      ],
    );
  });
}
