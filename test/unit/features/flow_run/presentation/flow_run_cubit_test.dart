import 'package:ataulfo/features/flow_run/domain/entities/runnable_flow.dart';
import 'package:ataulfo/features/flow_run/domain/failures/flow_run_failure.dart';
import 'package:ataulfo/features/flow_run/domain/repositories/flow_run_repository.dart';
import 'package:ataulfo/features/flow_run/presentation/bloc/flow_run_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowRunRepository {}

void main() {
  late _MockRepo repo;

  setUp(() => repo = _MockRepo());

  FlowRunCubit build() => FlowRunCubit(repo: repo, botId: 'b1');

  group('load', () {
    blocTest<FlowRunCubit, FlowRunState>(
      'éxito → [Loading, Loaded]',
      build: () {
        when(() => repo.listRunnable('b1')).thenAnswer(
          (_) async => const <RunnableFlow>[
            RunnableFlow(id: 'f1', name: 'Bienvenida'),
          ],
        );
        return build();
      },
      act: (c) => c.load(),
      expect: () => const <FlowRunState>[
        FlowRunLoading(),
        FlowRunLoaded(<RunnableFlow>[
          RunnableFlow(id: 'f1', name: 'Bienvenida'),
        ]),
      ],
    );

    blocTest<FlowRunCubit, FlowRunState>(
      'failure → [Loading, Failed]',
      build: () {
        when(
          () => repo.listRunnable('b1'),
        ).thenThrow(const FlowRunForbiddenFailure());
        return build();
      },
      act: (c) => c.load(),
      expect: () => const <FlowRunState>[
        FlowRunLoading(),
        FlowRunFailed(FlowRunForbiddenFailure()),
      ],
    );
  });

  group('run', () {
    test('éxito → RunStarted(executionId)', () async {
      when(
        () => repo.run(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          flowId: any(named: 'flowId'),
        ),
      ).thenAnswer((_) async => 'exe-9');
      final outcome = await build().run(chatLid: 'c1', flowId: 'f1');
      expect(outcome, isA<RunStarted>());
      expect((outcome as RunStarted).executionId, 'exe-9');
    });

    test('gate-block → RunBlocked(reason)', () async {
      when(
        () => repo.run(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          flowId: any(named: 'flowId'),
        ),
      ).thenThrow(const FlowRunBlockedFailure('COOLDOWN'));
      final outcome = await build().run(chatLid: 'c1', flowId: 'f1');
      expect(outcome, isA<RunBlocked>());
      expect((outcome as RunBlocked).reason, 'COOLDOWN');
    });

    test('paused → RunError', () async {
      when(
        () => repo.run(
          botId: any(named: 'botId'),
          chatLid: any(named: 'chatLid'),
          flowId: any(named: 'flowId'),
        ),
      ).thenThrow(const FlowRunPausedFailure());
      final outcome = await build().run(chatLid: 'c1', flowId: 'f1');
      expect(outcome, isA<RunError>());
      expect((outcome as RunError).failure, isA<FlowRunPausedFailure>());
    });
  });
}
