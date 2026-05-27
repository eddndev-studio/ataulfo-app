import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/domain/repositories/flows_repository.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements FlowsRepository {}

const _steps = <fdom.Step>[
  fdom.Step(
    id: 's1',
    flowId: 'f1',
    type: fdom.StepType.text,
    order: 0,
    content: 'Hola',
    mediaRef: '',
    metadataJson: '{}',
    delayMs: 0,
    jitterPct: 0,
    aiOnly: false,
  ),
  fdom.Step(
    id: 's2',
    flowId: 'f1',
    type: fdom.StepType.image,
    order: 1,
    content: '',
    mediaRef: 'https://example.com/x.png',
    metadataJson: '{}',
    delayMs: 500,
    jitterPct: 5,
    aiOnly: false,
  ),
];

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  group('FlowStepsBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = FlowStepsBloc(repo: repo, flowId: 'f1');
      expect(bloc.state, const FlowStepsLoading());
      bloc.close();
    });

    blocTest<FlowStepsBloc, FlowStepsState>(
      'LoadRequested ok → Loaded(steps)',
      build: () {
        when(() => repo.listSteps('f1')).thenAnswer((_) async => _steps);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      act: (bloc) => bloc.add(const FlowStepsLoadRequested()),
      expect: () => const <FlowStepsState>[FlowStepsLoaded(_steps)],
      verify: (_) {
        verify(() => repo.listSteps('f1')).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'LoadRequested con lista vacía → Loaded([])',
      build: () {
        when(
          () => repo.listSteps('f1'),
        ).thenAnswer((_) async => const <fdom.Step>[]);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      act: (bloc) => bloc.add(const FlowStepsLoadRequested()),
      expect: () =>
          const <FlowStepsState>[FlowStepsLoaded(<fdom.Step>[])],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'listSteps falla con NotFound → Failed(NotFound)',
      build: () {
        when(() => repo.listSteps('f1')).thenAnswer(
          (_) => Future<List<fdom.Step>>.error(const FlowsNotFoundFailure()),
        );
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      act: (bloc) => bloc.add(const FlowStepsLoadRequested()),
      expect: () => const <FlowStepsState>[
        FlowStepsFailed(FlowsNotFoundFailure()),
      ],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'listSteps falla con ServerFailure → Failed(Server)',
      build: () {
        when(() => repo.listSteps('f1')).thenAnswer(
          (_) => Future<List<fdom.Step>>.error(const FlowsServerFailure()),
        );
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      act: (bloc) => bloc.add(const FlowStepsLoadRequested()),
      expect: () => const <FlowStepsState>[
        FlowStepsFailed(FlowsServerFailure()),
      ],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'retry desde Failed re-emite Loading visible y luego Loaded',
      build: () {
        var calls = 0;
        when(() => repo.listSteps('f1')).thenAnswer((_) {
          calls++;
          if (calls == 1) {
            return Future<List<fdom.Step>>.error(const FlowsServerFailure());
          }
          return Future<List<fdom.Step>>.value(_steps);
        });
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      act: (bloc) async {
        bloc.add(const FlowStepsLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FlowStepsLoadRequested());
      },
      expect: () => const <FlowStepsState>[
        FlowStepsFailed(FlowsServerFailure()),
        FlowStepsLoading(),
        FlowStepsLoaded(_steps),
      ],
    );

    test('Loaded value-equality', () {
      const a = FlowStepsLoaded(_steps);
      const b = FlowStepsLoaded(_steps);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
