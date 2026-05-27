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
  setUpAll(() {
    registerFallbackValue(fdom.StepType.text);
  });

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
      expect: () => const <FlowStepsState>[FlowStepsLoaded(<fdom.Step>[])],
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

  group('FlowStepsBloc.AddRequested', () {
    const newStep = fdom.Step(
      id: 's-new',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 2,
      content: 'Bienvenida v2',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );
    const afterAdd = <fdom.Step>[..._steps, newStep];

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested ok desde Loaded → Mutating + Loading + Loaded(refrescado)',
      build: () {
        when(() => repo.listSteps('f1')).thenAnswer((_) async => afterAdd);
        when(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 2,
            content: 'Bienvenida v2',
            mediaRef: '',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).thenAnswer((_) async => newStep);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: 'Bienvenida v2',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsLoading(),
        FlowStepsLoaded(afterAdd),
      ],
      verify: (_) {
        verify(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 2,
            content: 'Bienvenida v2',
            mediaRef: '',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).called(1);
        verify(() => repo.listSteps('f1')).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested desde Loaded vacío → order=0',
      build: () {
        when(
          () => repo.listSteps('f1'),
        ).thenAnswer((_) async => const <fdom.Step>[]);
        when(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'X',
            mediaRef: '',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).thenAnswer((_) async => newStep.copyWith(order: 0, content: 'X'));
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(<fdom.Step>[]),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: 'X',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      verify: (_) {
        verify(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'X',
            mediaRef: '',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested falla 422 → Mutating + MutationFailed(steps intactos)',
      build: () {
        when(
          () => repo.createStep(
            flowId: any(named: 'flowId'),
            type: any(named: 'type'),
            order: any(named: 'order'),
            content: any(named: 'content'),
            mediaRef: any(named: 'mediaRef'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        ).thenThrow(const FlowsInvalidStepFailure());
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsMutationFailed(_steps, FlowsInvalidStepFailure()),
      ],
      verify: (_) {
        verifyNever(() => repo.listSteps('f1'));
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested desde MutationFailed (recovery) → consume snapshot del failed',
      build: () {
        when(
          () => repo.createStep(
            flowId: any(named: 'flowId'),
            type: any(named: 'type'),
            order: any(named: 'order'),
            content: any(named: 'content'),
            mediaRef: any(named: 'mediaRef'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        ).thenAnswer((_) async => newStep);
        when(() => repo.listSteps('f1')).thenAnswer((_) async => afterAdd);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () =>
          const FlowStepsMutationFailed(_steps, FlowsInvalidStepFailure()),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: 'Bienvenida v2',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsLoading(),
        FlowStepsLoaded(afterAdd),
      ],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested desde Loading → no-op (sin snapshot no se puede mutar)',
      build: () => FlowStepsBloc(repo: repo, flowId: 'f1'),
      seed: () => const FlowStepsLoading(),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: 'X',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      expect: () => const <FlowStepsState>[],
      verify: (_) {
        verifyNever(
          () => repo.createStep(
            flowId: any(named: 'flowId'),
            type: any(named: 'type'),
            order: any(named: 'order'),
            content: any(named: 'content'),
            mediaRef: any(named: 'mediaRef'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        );
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested éxito + listSteps falla → Failed (no enmascarar mutación)',
      build: () {
        when(
          () => repo.createStep(
            flowId: any(named: 'flowId'),
            type: any(named: 'type'),
            order: any(named: 'order'),
            content: any(named: 'content'),
            mediaRef: any(named: 'mediaRef'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        ).thenAnswer((_) async => newStep);
        when(() => repo.listSteps('f1')).thenAnswer(
          (_) => Future<List<fdom.Step>>.error(const FlowsServerFailure()),
        );
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          content: 'X',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsLoading(),
        FlowStepsFailed(FlowsServerFailure()),
      ],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'AddRequested con type=image + mediaRef → createStep recibe IMAGE',
      build: () {
        final imgStep = newStep.copyWith(
          type: fdom.StepType.image,
          mediaRef: 'http://x.png',
          content: 'cap',
        );
        when(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 2,
            content: 'cap',
            mediaRef: 'http://x.png',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).thenAnswer((_) async => imgStep);
        when(
          () => repo.listSteps('f1'),
        ).thenAnswer((_) async => <fdom.Step>[..._steps, imgStep]);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsAddRequested(
          type: fdom.StepType.image,
          mediaRef: 'http://x.png',
          content: 'cap',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
      ),
      verify: (_) {
        verify(
          () => repo.createStep(
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 2,
            content: 'cap',
            mediaRef: 'http://x.png',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ).called(1);
      },
    );

    test('Mutating + MutationFailed value-equality', () {
      const a = FlowStepsMutating(_steps);
      const b = FlowStepsMutating(_steps);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      const f1 = FlowStepsMutationFailed(_steps, FlowsInvalidStepFailure());
      const f2 = FlowStepsMutationFailed(_steps, FlowsInvalidStepFailure());
      expect(f1, equals(f2));
      expect(f1.hashCode, f2.hashCode);
    });
  });

  group('FlowStepsBloc.UpdateRequested', () {
    const patched = fdom.Step(
      id: 's1',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 0,
      content: 'Hola edited',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );
    const afterPatch = <fdom.Step>[
      patched,
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

    blocTest<FlowStepsBloc, FlowStepsState>(
      'UpdateRequested ok desde Loaded → Mutating + Loading + Loaded(refrescado)',
      build: () {
        when(
          () => repo.patchStep(stepId: 's1', content: 'Hola edited'),
        ).thenAnswer((_) async => patched);
        when(() => repo.listSteps('f1')).thenAnswer((_) async => afterPatch);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsUpdateRequested(stepId: 's1', content: 'Hola edited'),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsLoading(),
        FlowStepsLoaded(afterPatch),
      ],
      verify: (_) {
        verify(
          () => repo.patchStep(stepId: 's1', content: 'Hola edited'),
        ).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'UpdateRequested propaga todos los campos opcionales',
      build: () {
        when(
          () => repo.patchStep(
            stepId: 's1',
            content: 'X',
            delayMs: 2000,
            jitterPct: 10,
            aiOnly: true,
          ),
        ).thenAnswer((_) async => patched);
        when(() => repo.listSteps('f1')).thenAnswer((_) async => afterPatch);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsUpdateRequested(
          stepId: 's1',
          content: 'X',
          delayMs: 2000,
          jitterPct: 10,
          aiOnly: true,
        ),
      ),
      verify: (_) {
        verify(
          () => repo.patchStep(
            stepId: 's1',
            content: 'X',
            delayMs: 2000,
            jitterPct: 10,
            aiOnly: true,
          ),
        ).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'UpdateRequested falla → MutationFailed(steps intactos)',
      build: () {
        when(
          () => repo.patchStep(
            stepId: any(named: 'stepId'),
            content: any(named: 'content'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        ).thenThrow(const FlowsStepNotFoundFailure());
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(_steps),
      act: (bloc) => bloc.add(
        const FlowStepsUpdateRequested(stepId: 'gone', content: 'X'),
      ),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(_steps),
        FlowStepsMutationFailed(_steps, FlowsStepNotFoundFailure()),
      ],
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'UpdateRequested desde Loading → no-op',
      build: () => FlowStepsBloc(repo: repo, flowId: 'f1'),
      seed: () => const FlowStepsLoading(),
      act: (bloc) =>
          bloc.add(const FlowStepsUpdateRequested(stepId: 's1', content: 'X')),
      expect: () => const <FlowStepsState>[],
      verify: (_) {
        verifyNever(
          () => repo.patchStep(
            stepId: any(named: 'stepId'),
            content: any(named: 'content'),
            delayMs: any(named: 'delayMs'),
            jitterPct: any(named: 'jitterPct'),
            aiOnly: any(named: 'aiOnly'),
          ),
        );
      },
    );
  });

  group('FlowStepsBloc.ReorderRequested', () {
    // Tres steps para que el reorder pueda generar ≥2 patches y deje
    // visible el caso de skip cuando algún id ya está en su lugar.
    const s1 = fdom.Step(
      id: 's1',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 0,
      content: 'A',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );
    const s2 = fdom.Step(
      id: 's2',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 1,
      content: 'B',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );
    const s3 = fdom.Step(
      id: 's3',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 2,
      content: 'C',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );
    const seedSteps = <fdom.Step>[s1, s2, s3];
    // Tras reorder [s1, s3, s2] el backend devolverá la lista refrescada
    // ordenada por `order` ASC. s1 mantiene su posición (skip de patch).
    const afterReorder = <fdom.Step>[
      s1,
      fdom.Step(
        id: 's3',
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 1,
        content: 'C',
        mediaRef: '',
        metadataJson: '{}',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      ),
      fdom.Step(
        id: 's2',
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 2,
        content: 'B',
        mediaRef: '',
        metadataJson: '{}',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      ),
    ];

    blocTest<FlowStepsBloc, FlowStepsState>(
      'ReorderRequested ok → N×patchStep(order) con skip + Loading + Loaded',
      build: () {
        // Patches solo para los ids que cambiaron de order. s1 (i=0
        // tras reorder, original=0) NO debe ser pateado.
        when(
          () => repo.patchStep(stepId: 's3', order: 1),
        ).thenAnswer((_) async => afterReorder[1]);
        when(
          () => repo.patchStep(stepId: 's2', order: 2),
        ).thenAnswer((_) async => afterReorder[2]);
        when(() => repo.listSteps('f1')).thenAnswer((_) async => afterReorder);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(seedSteps),
      act: (bloc) =>
          bloc.add(const FlowStepsReorderRequested(<String>['s1', 's3', 's2'])),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(seedSteps),
        FlowStepsLoading(),
        FlowStepsLoaded(afterReorder),
      ],
      verify: (_) {
        // s1 mantiene order=0 — el bloc skipea para no gastar request.
        verifyNever(() => repo.patchStep(stepId: 's1', order: 0));
        verify(() => repo.patchStep(stepId: 's3', order: 1)).called(1);
        verify(() => repo.patchStep(stepId: 's2', order: 2)).called(1);
        verify(() => repo.listSteps('f1')).called(1);
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'ReorderRequested sin cambios reales → no patches, igual refetch',
      build: () {
        when(() => repo.listSteps('f1')).thenAnswer((_) async => seedSteps);
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(seedSteps),
      // Mismos ids en el mismo orden que el snapshot vigente.
      act: (bloc) =>
          bloc.add(const FlowStepsReorderRequested(<String>['s1', 's2', 's3'])),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(seedSteps),
        FlowStepsLoading(),
        FlowStepsLoaded(seedSteps),
      ],
      verify: (_) {
        verifyNever(
          () => repo.patchStep(
            stepId: any(named: 'stepId'),
            order: any(named: 'order'),
          ),
        );
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'ReorderRequested falla a mitad → MutationFailed(snapshot original)',
      build: () {
        // Primera patch ok, segunda revienta con StepNotFound (otro
        // operador borró el step entre el listado y el drag).
        when(
          () => repo.patchStep(stepId: 's3', order: 0),
        ).thenAnswer((_) async => afterReorder[0]);
        when(
          () => repo.patchStep(stepId: 's1', order: 1),
        ).thenThrow(const FlowsStepNotFoundFailure());
        return FlowStepsBloc(repo: repo, flowId: 'f1');
      },
      seed: () => const FlowStepsLoaded(seedSteps),
      act: (bloc) =>
          bloc.add(const FlowStepsReorderRequested(<String>['s3', 's1', 's2'])),
      expect: () => const <FlowStepsState>[
        FlowStepsMutating(seedSteps),
        FlowStepsMutationFailed(seedSteps, FlowsStepNotFoundFailure()),
      ],
      verify: (_) {
        // No refetch tras el fallo — el backend quedó parcial; el bloc
        // deja que el operador reintente o haga reload manual.
        verifyNever(() => repo.listSteps('f1'));
      },
    );

    blocTest<FlowStepsBloc, FlowStepsState>(
      'ReorderRequested desde Loading → no-op',
      build: () => FlowStepsBloc(repo: repo, flowId: 'f1'),
      seed: () => const FlowStepsLoading(),
      act: (bloc) =>
          bloc.add(const FlowStepsReorderRequested(<String>['s3', 's1', 's2'])),
      expect: () => const <FlowStepsState>[],
      verify: (_) {
        verifyNever(
          () => repo.patchStep(
            stepId: any(named: 'stepId'),
            order: any(named: 'order'),
          ),
        );
      },
    );

    test('ReorderRequested value-equality', () {
      const a = FlowStepsReorderRequested(<String>['a', 'b']);
      const b = FlowStepsReorderRequested(<String>['a', 'b']);
      const c = FlowStepsReorderRequested(<String>['b', 'a']);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
