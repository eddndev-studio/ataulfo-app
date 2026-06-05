import 'package:ataulfo/features/flows/domain/entities/flow.dart';
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowsRepository {}

const _flow1 = Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _flow2 = Flow(
  id: 'f2',
  templateId: 't1',
  name: 'Despedida',
  isActive: false,
  version: 2,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _flows = <Flow>[_flow1, _flow2];

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('FlowsBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = FlowsBloc(repo: repo, templateId: 't1');
      expect(bloc.state, const FlowsLoading());
      bloc.close();
    });

    blocTest<FlowsBloc, FlowsState>(
      'LoadRequested ok → Loaded(flows) (no re-emite Loading post-construcción)',
      build: () {
        when(() => repo.listFlows('t1')).thenAnswer((_) async => _flows);
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const FlowsLoadRequested()),
      expect: () => const <FlowsState>[FlowsLoaded(_flows)],
      verify: (_) => verify(() => repo.listFlows('t1')).called(1),
    );

    blocTest<FlowsBloc, FlowsState>(
      'LoadRequested ok con lista vacía → Loaded([]) (template sin flows)',
      build: () {
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[]);
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const FlowsLoadRequested()),
      expect: () => const <FlowsState>[FlowsLoaded(<Flow>[])],
    );

    blocTest<FlowsBloc, FlowsState>(
      'LoadRequested 404 → Failed(NotFound)',
      build: () {
        when(() => repo.listFlows('t1')).thenAnswer(
          (_) => Future<List<Flow>>.error(const FlowsNotFoundFailure()),
        );
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) => bloc.add(const FlowsLoadRequested()),
      expect: () => const <FlowsState>[FlowsFailed(FlowsNotFoundFailure())],
    );

    blocTest<FlowsBloc, FlowsState>(
      'retry desde Failed re-emite Loading visible y luego Loaded',
      build: () {
        var calls = 0;
        when(() => repo.listFlows('t1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<List<Flow>>.error(const FlowsServerFailure());
          }
          return Future<List<Flow>>.value(_flows);
        });
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      act: (bloc) async {
        bloc.add(const FlowsLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FlowsLoadRequested());
      },
      expect: () => const <FlowsState>[
        FlowsFailed(FlowsServerFailure()),
        FlowsLoading(),
        FlowsLoaded(_flows),
      ],
      verify: (_) => verify(() => repo.listFlows('t1')).called(2),
    );

    blocTest<FlowsBloc, FlowsState>(
      'DeleteRequested ok → Mutating(snapshot) → Loading → Loaded(refetch)',
      build: () {
        when(() => repo.deleteFlow('f1')).thenAnswer((_) async {});
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[_flow2]);
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      seed: () => const FlowsLoaded(_flows),
      act: (bloc) => bloc.add(const FlowsDeleteRequested('f1')),
      expect: () => const <FlowsState>[
        FlowsMutating(_flows),
        FlowsLoading(),
        FlowsLoaded(<Flow>[_flow2]),
      ],
      verify: (_) {
        verify(() => repo.deleteFlow('f1')).called(1);
        verify(() => repo.listFlows('t1')).called(1);
      },
    );

    blocTest<FlowsBloc, FlowsState>(
      'DeleteRequested falla → Mutating → MutationFailed (lista intacta, sin refetch)',
      build: () {
        when(
          () => repo.deleteFlow('f1'),
        ).thenAnswer((_) => Future<void>.error(const FlowsForbiddenFailure()));
        return FlowsBloc(repo: repo, templateId: 't1');
      },
      seed: () => const FlowsLoaded(_flows),
      act: (bloc) => bloc.add(const FlowsDeleteRequested('f1')),
      expect: () => const <FlowsState>[
        FlowsMutating(_flows),
        FlowsMutationFailed(_flows, FlowsForbiddenFailure()),
      ],
      verify: (_) => verifyNever(() => repo.listFlows(any())),
    );

    blocTest<FlowsBloc, FlowsState>(
      'DeleteRequested sin lista vigente (Loading inicial) → no-op',
      build: () => FlowsBloc(repo: repo, templateId: 't1'),
      act: (bloc) => bloc.add(const FlowsDeleteRequested('f1')),
      expect: () => const <FlowsState>[],
      verify: (_) => verifyNever(() => repo.deleteFlow(any())),
    );

    test('Loaded value-equality', () {
      const a = FlowsLoaded(_flows);
      const b = FlowsLoaded(_flows);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Failed value-equality discrimina por failure', () {
      const a = FlowsFailed(FlowsServerFailure());
      const b = FlowsFailed(FlowsServerFailure());
      const c = FlowsFailed(FlowsNetworkFailure());
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
