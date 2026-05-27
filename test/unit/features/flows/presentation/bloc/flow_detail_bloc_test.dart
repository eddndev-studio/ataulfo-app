import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
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
);

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

  group('FlowDetailBloc', () {
    test('estado inicial = Loading (sin flash de Initial)', () {
      final bloc = FlowDetailBloc(repo: repo, id: 'f1');
      expect(bloc.state, const FlowDetailLoading());
      bloc.close();
    });

    blocTest<FlowDetailBloc, FlowDetailState>(
      'LoadRequested ok → Loaded(flow, steps) (paraleliza ambos GETs)',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        when(() => repo.listSteps('f1')).thenAnswer((_) async => _steps);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[FlowDetailLoaded(_flow, _steps)],
      verify: (_) {
        verify(() => repo.flowById('f1')).called(1);
        verify(() => repo.listSteps('f1')).called(1);
      },
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'LoadRequested con steps vacíos → Loaded(flow, [])',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        when(
          () => repo.listSteps('f1'),
        ).thenAnswer((_) async => const <fdom.Step>[]);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailLoaded(_flow, <fdom.Step>[]),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'flowById falla con NotFound → Failed(NotFound) (no espera a steps)',
      build: () {
        when(
          () => repo.flowById('f1'),
        ).thenAnswer((_) => Future<Flow>.error(const FlowsNotFoundFailure()));
        // listSteps puede o no resolverse — el bloc no debe colgarse.
        when(
          () => repo.listSteps('f1'),
        ).thenAnswer((_) async => const <fdom.Step>[]);
        return FlowDetailBloc(repo: repo, id: 'f1');
      },
      act: (bloc) => bloc.add(const FlowDetailLoadRequested()),
      expect: () => const <FlowDetailState>[
        FlowDetailFailed(FlowsNotFoundFailure()),
      ],
    );

    blocTest<FlowDetailBloc, FlowDetailState>(
      'listSteps falla → Failed (cabecera no se muestra si falla la lista)',
      build: () {
        when(() => repo.flowById('f1')).thenAnswer((_) async => _flow);
        when(() => repo.listSteps('f1')).thenAnswer(
          (_) => Future<List<fdom.Step>>.error(const FlowsServerFailure()),
        );
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
        when(() => repo.listSteps('f1')).thenAnswer((_) async => _steps);
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
        FlowDetailLoaded(_flow, _steps),
      ],
    );

    test('Loaded value-equality', () {
      const a = FlowDetailLoaded(_flow, _steps);
      const b = FlowDetailLoaded(_flow, _steps);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
