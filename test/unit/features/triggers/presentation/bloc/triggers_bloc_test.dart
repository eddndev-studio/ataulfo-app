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
  });
}
