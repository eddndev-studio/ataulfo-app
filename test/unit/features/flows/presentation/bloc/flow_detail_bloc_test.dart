import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/domain/repositories/flows_repository.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowsRepository {}

const _flow = Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 3,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _sibling1 = Flow(
  id: 'f2',
  templateId: 't1',
  name: 'Despedida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _sibling2 = Flow(
  id: 'f3',
  templateId: 't1',
  name: 'Recordatorio',
  isActive: false,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailLoadRequested());
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('FlowDetailBloc — load', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = FlowDetailBloc(repo: repo, id: 'f1');
      expect(bloc.state, const FlowDetailLoading());
      bloc.close();
    });

    blocTest<FlowDetailBloc, FlowDetailState>(
      'LoadRequested ok → Loaded(flow, siblings) — current flow filtrado de la lista',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[_flow, _sibling1, _sibling2]);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailLoaded(
          _flow,
          <Flow>[_sibling1, _sibling2],
          siblingsFailed: false,
        ),
      ],
      verify: (_) {
        verify(() => repo.flowById('f1')).called(1);
        verify(() => repo.listFlows('t1')).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById ok pero listFlows falla → Loaded degradado con siblings=[] + siblingsFailed=true',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        when(() => repo.listFlows('t1')).thenAnswer(
          (_) => Future<List<Flow>>.error(const FlowsServerFailure()),
        );
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailLoaded(_flow, <Flow>[], siblingsFailed: true),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById falla con NotFound → Failed (listFlows no se llama)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsNotFoundFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsNotFoundFailure()),
      ],
      verify: (_) {
        verifyNever(() => repo.listFlows(any()));
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById falla con ServerFailure → Failed(Server)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsServerFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsServerFailure()),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'retry desde Failed re-emite Loading visible y luego Loaded',
      build: () {
        var calls = 0;
        when(() => repo.flowById('f1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<Flow>.error(const FlowsServerFailure());
          }
          return Future<Flow>.value(_flow);
        });
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[_flow]);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) async {
        bloc.add(const FlowDetailLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FlowDetailLoadRequested());
      },
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsServerFailure()),
        FlowDetailLoading(),
        FlowDetailLoaded(_flow, <Flow>[], siblingsFailed: false),
      ],
    );

    test('Loaded value-equality', () {
      const a = FlowDetailLoaded(_flow, <Flow>[_sibling1], siblingsFailed: false);
      const b = FlowDetailLoaded(_flow, <Flow>[_sibling1], siblingsFailed: false);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Loaded NO es igual cuando cambia siblingsFailed', () {
      const a = FlowDetailLoaded(_flow, <Flow>[], siblingsFailed: false);
      const b = FlowDetailLoaded(_flow, <Flow>[], siblingsFailed: true);
      expect(a, isNot(equals(b)));
    });
  });

  group('FlowDetailBloc — update settings', () {
    const _flowV4 = Flow(
      id: 'f1',
      templateId: 't1',
      name: 'Bienvenida',
      isActive: true,
      version: 4,
      cooldownMs: 5000,
      usageLimit: 3,
      excludesFlows: <String>['f2'],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'UpdateSettingsRequested desde Loaded ok → Saving → Loading → Loaded(refrescado)',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flowV4);
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[_flowV4, _sibling1]);
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) async => _flowV4);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => const FlowDetailLoaded(
        _flow,
        <Flow>[_sibling1],
        siblingsFailed: false,
      ),
      act: (bloc) => bloc.add(
        const FlowDetailUpdateSettingsRequested(
          cooldownMs: 5000,
          usageLimit: 3,
          excludesFlows: <String>['f2'],
        ),
      ),
      expect: () => const <FlowDetailState>[
        FlowDetailSettingsSaving(
          _flow,
          <Flow>[_sibling1],
          siblingsFailed: false,
        ),
        FlowDetailLoading(),
        FlowDetailLoaded(_flowV4, <Flow>[_sibling1], siblingsFailed: false),
      ],
      verify: (_) {
        // El PUT recibe name + isActive + version del snapshot, no del evento.
        verify(
          () => repo.updateFlow(
            flowId: 'f1',
            version: 3,
            name: 'Bienvenida',
            isActive: true,
            cooldownMs: 5000,
            usageLimit: 3,
            excludesFlows: const <String>['f2'],
          ),
        ).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      '409 → SettingsSaveFailed(snapshot, Conflict) — preserva flow + siblings',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenThrow(const FlowsConflictFailure());
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => const FlowDetailLoaded(
        _flow,
        <Flow>[_sibling1, _sibling2],
        siblingsFailed: false,
      ),
      act: (bloc) => bloc.add(
        const FlowDetailUpdateSettingsRequested(
          cooldownMs: 0,
          usageLimit: 0,
          excludesFlows: <String>[],
        ),
      ),
      expect: () => const <FlowDetailState>[
        FlowDetailSettingsSaving(
          _flow,
          <Flow>[_sibling1, _sibling2],
          siblingsFailed: false,
        ),
        FlowDetailSettingsSaveFailed(
          _flow,
          <Flow>[_sibling1, _sibling2],
          FlowsConflictFailure(),
          siblingsFailed: false,
        ),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      '422 → SettingsSaveFailed(snapshot, InvalidSettings)',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenThrow(const FlowsInvalidSettingsFailure());
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => const FlowDetailLoaded(
        _flow,
        <Flow>[],
        siblingsFailed: false,
      ),
      act: (bloc) => bloc.add(
        const FlowDetailUpdateSettingsRequested(
          cooldownMs: -1,
          usageLimit: 0,
          excludesFlows: <String>[],
        ),
      ),
      expect: () => const <FlowDetailState>[
        FlowDetailSettingsSaving(_flow, <Flow>[], siblingsFailed: false),
        FlowDetailSettingsSaveFailed(
          _flow,
          <Flow>[],
          FlowsInvalidSettingsFailure(),
          siblingsFailed: false,
        ),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'UpdateSettings desde Loading se ignora (no hay snapshot fiable)',
      build: () => FlowDetailBloc(repo: repo, id: 'f1'),
      act: (bloc) => bloc.add(
        const FlowDetailUpdateSettingsRequested(
          cooldownMs: 0,
          usageLimit: 0,
          excludesFlows: <String>[],
        ),
      ),
      expect: () => const <FlowDetailState>[],
      verify: (_) {
        verifyNever(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        );
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'UpdateSettings desde SettingsSaveFailed reusa el snapshot (segundo intento)',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flowV4);
        when(
          () => repo.listFlows('t1'),
        ).thenAnswer((_) async => const <Flow>[_flowV4]);
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) async => _flowV4);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => const FlowDetailSettingsSaveFailed(
        _flow,
        <Flow>[],
        FlowsInvalidSettingsFailure(),
        siblingsFailed: false,
      ),
      act: (bloc) => bloc.add(
        const FlowDetailUpdateSettingsRequested(
          cooldownMs: 5000,
          usageLimit: 3,
          excludesFlows: <String>['f2'],
        ),
      ),
      expect: () => const <FlowDetailState>[
        FlowDetailSettingsSaving(_flow, <Flow>[], siblingsFailed: false),
        FlowDetailLoading(),
        FlowDetailLoaded(_flowV4, <Flow>[], siblingsFailed: false),
      ],
    );
  });
}
