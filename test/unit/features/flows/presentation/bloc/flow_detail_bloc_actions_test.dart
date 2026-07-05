import 'package:ataulfo/features/flows/domain/entities/flow.dart';
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
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
  cooldownMs: 5000,
  usageLimit: 2,
  excludesFlows: <String>['f9'],
);

const _sibling = Flow(
  id: 'f2',
  templateId: 't1',
  name: 'Despedida',
  isActive: true,
  version: 1,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

const _seeded = FlowDetailLoaded(_flow, <Flow>[
  _sibling,
], siblingsFailed: false);

/// Acciones de cabecera del editor de flujo: renombrar, pausar/activar,
/// eliminar y el refresh que conserva el snapshot. Todas exigen snapshot
/// (Loaded / MutationFailed) y reusan el PUT replace-completo del repo, así
/// que los campos que la acción NO toca viajan intactos desde el snapshot.
void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Flow updated({String? name, bool? isActive}) => Flow(
    id: _flow.id,
    templateId: _flow.templateId,
    name: name ?? _flow.name,
    isActive: isActive ?? _flow.isActive,
    version: _flow.version + 1,
    cooldownMs: _flow.cooldownMs,
    usageLimit: _flow.usageLimit,
    excludesFlows: _flow.excludesFlows,
  );

  group('FlowDetailRenameRequested', () {
    blocTest<FlowDetailBloc, FlowDetailState>(
      'ok → Mutating → Loaded con el flow del PUT (siblings intactos); '
      'el resto de campos viaja desde el snapshot',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            aiInvocable: any(named: 'aiInvocable'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) async => updated(name: 'Onboarding'));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailRenameRequested('Onboarding')),
      expect: () => <FlowDetailState>[
        const FlowDetailMutating(_flow, <Flow>[
          _sibling,
        ], siblingsFailed: false),
        FlowDetailLoaded(updated(name: 'Onboarding'), const <Flow>[
          _sibling,
        ], siblingsFailed: false),
      ],
      verify: (_) {
        verify(
          () => repo.updateFlow(
            flowId: 'f1',
            version: 3,
            name: 'Onboarding',
            isActive: true,
            aiInvocable: false,
            cooldownMs: 5000,
            usageLimit: 2,
            excludesFlows: const <String>['f9'],
          ),
        ).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      '409 → MutationFailed(snapshot, Conflict) — el snapshot no se pierde',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            aiInvocable: any(named: 'aiInvocable'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsConflictFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailRenameRequested('Onboarding')),
      expect: () => const <FlowDetailState>[
        FlowDetailMutating(_flow, <Flow>[_sibling], siblingsFailed: false),
        FlowDetailMutationFailed(
          _flow,
          <Flow>[_sibling],
          FlowsConflictFailure(),
          siblingsFailed: false,
        ),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'sin snapshot (Loading) → no-op',
      build: () => FlowDetailBloc(repo: repo, id: 'f1'),
      act: (bloc) => bloc.add(const FlowDetailRenameRequested('Onboarding')),
      expect: () => const <FlowDetailState>[],
      verify: (_) {
        verifyNever(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            aiInvocable: any(named: 'aiInvocable'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        );
      },
    );
  });

  group('FlowDetailSetActiveRequested', () {
    blocTest<FlowDetailBloc, FlowDetailState>(
      'pausar (isActive=false) → Mutating → Loaded con el flow del PUT',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            aiInvocable: any(named: 'aiInvocable'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) async => updated(isActive: false));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailSetActiveRequested(false)),
      expect: () => <FlowDetailState>[
        const FlowDetailMutating(_flow, <Flow>[
          _sibling,
        ], siblingsFailed: false),
        FlowDetailLoaded(updated(isActive: false), const <Flow>[
          _sibling,
        ], siblingsFailed: false),
      ],
      verify: (_) {
        verify(
          () => repo.updateFlow(
            flowId: 'f1',
            version: 3,
            name: 'Bienvenida',
            isActive: false,
            aiInvocable: false,
            cooldownMs: 5000,
            usageLimit: 2,
            excludesFlows: const <String>['f9'],
          ),
        ).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'fallo del PUT → MutationFailed(snapshot, failure)',
      build: () {
        when(
          () => repo.updateFlow(
            flowId: any(named: 'flowId'),
            version: any(named: 'version'),
            name: any(named: 'name'),
            isActive: any(named: 'isActive'),
            aiInvocable: any(named: 'aiInvocable'),
            cooldownMs: any(named: 'cooldownMs'),
            usageLimit: any(named: 'usageLimit'),
            excludesFlows: any(named: 'excludesFlows'),
          ),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsServerFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailSetActiveRequested(false)),
      expect: () => const <FlowDetailState>[
        FlowDetailMutating(_flow, <Flow>[_sibling], siblingsFailed: false),
        FlowDetailMutationFailed(
          _flow,
          <Flow>[_sibling],
          FlowsServerFailure(),
          siblingsFailed: false,
        ),
      ],
    );
  });

  group('FlowDetailDeleteRequested', () {
    blocTest<FlowDetailBloc, FlowDetailState>(
      'ok → Mutating → Deleted (terminal; la página navega de regreso)',
      build: () {
        when(() => repo.deleteFlow('f1')).thenAnswer((_) async {});
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailDeleteRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailMutating(_flow, <Flow>[_sibling], siblingsFailed: false),
        FlowDetailDeleted(),
      ],
      verify: (_) {
        verify(() => repo.deleteFlow('f1')).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'fallo → MutationFailed(snapshot, failure) — el editor sigue usable',
      build: () {
        when(
          () => repo.deleteFlow('f1'),
        ).thenAnswer((_) => Future<void>.error(const FlowsForbiddenFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailDeleteRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailMutating(_flow, <Flow>[_sibling], siblingsFailed: false),
        FlowDetailMutationFailed(
          _flow,
          <Flow>[_sibling],
          FlowsForbiddenFailure(),
          siblingsFailed: false,
        ),
      ],
    );
  });

  group('FlowDetailRefreshRequested', () {
    blocTest<FlowDetailBloc, FlowDetailState>(
      'con snapshot → Loaded fresco SIN pasar por Loading',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) async => updated(name: 'Renombrado fuera'));
        when(() => repo.listFlows('t1')).thenAnswer(
          (_) async => <Flow>[updated(name: 'Renombrado fuera'), _sibling],
        );
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailRefreshRequested()),
      expect: () => <FlowDetailState>[
        FlowDetailLoaded(updated(name: 'Renombrado fuera'), const <Flow>[
          _sibling,
        ], siblingsFailed: false),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'fallo del refetch → conserva el snapshot en silencio (best-effort)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsNetworkFailure()));
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      seed: () => _seeded,
      act: (bloc) => bloc.add(const FlowDetailRefreshRequested()),
      expect: () => const <FlowDetailState>[],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'sin snapshot (Loading) → no-op (la carga inicial ya está en vuelo)',
      build: () => FlowDetailBloc(repo: repo, id: 'f1'),
      act: (bloc) => bloc.add(const FlowDetailRefreshRequested()),
      expect: () => const <FlowDetailState>[],
      verify: (_) {
        verifyNever(() => repo.flowById(any()));
      },
    );
  });
}
