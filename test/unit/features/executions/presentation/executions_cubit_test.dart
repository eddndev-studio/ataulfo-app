import 'package:ataulfo/features/executions/domain/entities/execution.dart';
import 'package:ataulfo/features/executions/domain/execution_repository.dart';
import 'package:ataulfo/features/executions/domain/failures/execution_failure.dart';
import 'package:ataulfo/features/executions/presentation/cubit/executions_cubit.dart';
import 'package:ataulfo/features/flow_run/domain/entities/runnable_flow.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockExecRepo extends Mock implements ExecutionRepository {}

class _MockFlowRunRepo extends Mock implements FlowRunRepository {}

Execution _exe(String id, ExecutionStatus status, String flowId) => Execution(
  id: id,
  botId: 'b1',
  chatLid: 'c1',
  flowId: flowId,
  templateId: 'tpl-1',
  status: status,
  error: status == ExecutionStatus.failed ? 'boom' : '',
  currentStep: 1,
  startedAt: DateTime.utc(2026, 6, 14, 9),
  endedAt: status == ExecutionStatus.running
      ? null
      : DateTime.utc(2026, 6, 14, 9, 1),
);

void main() {
  late _MockExecRepo exec;
  late _MockFlowRunRepo flows;

  setUp(() {
    exec = _MockExecRepo();
    flows = _MockFlowRunRepo();
  });

  ExecutionsCubit build() => ExecutionsCubit(
    execRepo: exec,
    flowRunRepo: flows,
    botId: 'b1',
    chatLid: 'c1',
  );

  blocTest<ExecutionsCubit, ExecutionsState>(
    'load → Loaded con ejecuciones y nombres de flujo resueltos',
    setUp: () {
      when(() => exec.listBySession(botId: 'b1', chatLid: 'c1')).thenAnswer(
        (_) async => <Execution>[
          _exe('exe-1', ExecutionStatus.failed, 'flw-1'),
        ],
      );
      when(() => flows.listRunnable('b1')).thenAnswer(
        (_) async => const <RunnableFlow>[
          RunnableFlow(id: 'flw-1', name: 'Bienvenida'),
        ],
      );
    },
    build: build,
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<ExecutionsLoaded>()
          .having((s) => s.executions.length, 'executions', 1)
          .having((s) => s.flowNames['flw-1'], 'nombre resuelto', 'Bienvenida'),
    ],
  );

  blocTest<ExecutionsCubit, ExecutionsState>(
    'fallo de ejecuciones → Failed',
    setUp: () {
      when(
        () => exec.listBySession(botId: 'b1', chatLid: 'c1'),
      ).thenThrow(const ExecutionForbiddenFailure());
    },
    build: build,
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<ExecutionsFailed>().having(
        (s) => s.failure,
        'failure',
        isA<ExecutionForbiddenFailure>(),
      ),
    ],
  );

  blocTest<ExecutionsCubit, ExecutionsState>(
    'fallo al resolver nombres es best-effort: sigue Loaded sin nombres',
    setUp: () {
      when(() => exec.listBySession(botId: 'b1', chatLid: 'c1')).thenAnswer(
        (_) async => <Execution>[
          _exe('exe-1', ExecutionStatus.failed, 'flw-9'),
        ],
      );
      when(() => flows.listRunnable('b1')).thenThrow(Exception('flows down'));
    },
    build: build,
    act: (c) => c.load(),
    expect: () => <Matcher>[
      isA<ExecutionsLoaded>()
          .having((s) => s.executions.length, 'executions', 1)
          .having((s) => s.flowNames.isEmpty, 'sin nombres', true),
    ],
  );

  // El cubit es page-scoped: al hacer pop de la pantalla el BlocProvider lo
  // cierra. Si load() está en vuelo (entre un await y su emit) el emit caería
  // sobre un controller cerrado y lanzaría StateError en un Future no-aguardado
  // (la app no tiene guard global de errores async). El load cancelado debe
  // descartarse en silencio.
  test('close() en vuelo: el emit de Loaded se descarta sin lanzar', () async {
    when(() => exec.listBySession(botId: 'b1', chatLid: 'c1')).thenAnswer((
      _,
    ) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return <Execution>[_exe('exe-1', ExecutionStatus.failed, 'flw-1')];
    });
    when(
      () => flows.listRunnable('b1'),
    ).thenAnswer((_) async => const <RunnableFlow>[]);

    final cubit = build();
    final pending = cubit.load();
    await cubit.close();

    await expectLater(pending, completes);
  });

  test('close() en vuelo: el emit de Failed se descarta sin lanzar', () async {
    when(() => exec.listBySession(botId: 'b1', chatLid: 'c1')).thenAnswer((
      _,
    ) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      throw const ExecutionForbiddenFailure();
    });

    final cubit = build();
    final pending = cubit.load();
    await cubit.close();

    await expectLater(pending, completes);
  });
}
