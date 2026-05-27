import 'package:agentic/features/flows/data/datasources/flows_datasource.dart';
import 'package:agentic/features/flows/data/repositories/flows_repository_impl.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements FlowsDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(fdom.StepType.text);
  });

  late _MockDatasource ds;
  late FlowsRepositoryImpl repo;

  setUp(() {
    ds = _MockDatasource();
    repo = FlowsRepositoryImpl(datasource: ds);
  });

  group('FlowsRepositoryImpl.listFlows', () {
    test('delega al datasource y devuelve la lista intacta', () async {
      when(() => ds.listFlows('t1')).thenAnswer(
        (_) async => const <Flow>[
          Flow(
            id: 'f1',
            templateId: 't1',
            name: 'Bienvenida',
            isActive: true,
            version: 1,
            cooldownMs: 0,
            usageLimit: 0,
            excludesFlows: <String>[],
          ),
        ],
      );

      final res = await repo.listFlows('t1');

      expect(res, hasLength(1));
      expect(res.first.id, 'f1');
      verify(() => ds.listFlows('t1')).called(1);
    });

    test('propaga failures del datasource sin envolver', () async {
      when(() => ds.listFlows('t1')).thenAnswer(
        (_) => Future<List<Flow>>.error(const FlowsNetworkFailure()),
      );

      await expectLater(
        repo.listFlows('t1'),
        throwsA(isA<FlowsNetworkFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.flowById', () {
    test('delega y devuelve la cabecera', () async {
      when(() => ds.flowById('f1')).thenAnswer(
        (_) async => const Flow(
          id: 'f1',
          templateId: 't1',
          name: 'Bienvenida',
          isActive: true,
          version: 1,
          cooldownMs: 0,
          usageLimit: 0,
          excludesFlows: <String>[],
        ),
      );

      final flow = await repo.flowById('f1');

      expect(flow.id, 'f1');
      verify(() => ds.flowById('f1')).called(1);
    });

    test('propaga failures sin envolver', () async {
      when(
        () => ds.flowById('missing'),
      ).thenAnswer((_) => Future<Flow>.error(const FlowsNotFoundFailure()));
      await expectLater(
        repo.flowById('missing'),
        throwsA(isA<FlowsNotFoundFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.listSteps', () {
    test('delega y devuelve la lista intacta', () async {
      when(() => ds.listSteps('f1')).thenAnswer(
        (_) async => const <fdom.Step>[
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
        ],
      );

      final steps = await repo.listSteps('f1');

      expect(steps, hasLength(1));
      verify(() => ds.listSteps('f1')).called(1);
    });

    test('propaga failures sin envolver', () async {
      when(() => ds.listSteps('f1')).thenAnswer(
        (_) => Future<List<fdom.Step>>.error(const FlowsServerFailure()),
      );
      await expectLater(
        repo.listSteps('f1'),
        throwsA(isA<FlowsServerFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.createFlow', () {
    test('delega 1:1 al datasource', () async {
      when(() => ds.createFlow(templateId: 't1', name: 'X')).thenAnswer(
        (_) async => const Flow(
          id: 'f-new',
          templateId: 't1',
          name: 'X',
          isActive: true,
          version: 1,
          cooldownMs: 0,
          usageLimit: 0,
          excludesFlows: <String>[],
        ),
      );
      final out = await repo.createFlow(templateId: 't1', name: 'X');
      expect(out.id, 'f-new');
      verify(() => ds.createFlow(templateId: 't1', name: 'X')).called(1);
    });

    test('relanza FlowsFailure del datasource sin envolver', () async {
      when(
        () => ds.createFlow(templateId: 't1', name: ''),
      ).thenThrow(const FlowsInvalidCreateFailure());
      await expectLater(
        () => repo.createFlow(templateId: 't1', name: ''),
        throwsA(isA<FlowsInvalidCreateFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.updateFlow', () {
    test('delega 1:1 al datasource con todos los campos del body', () async {
      when(
        () => ds.updateFlow(
          flowId: any(named: 'flowId'),
          version: any(named: 'version'),
          name: any(named: 'name'),
          isActive: any(named: 'isActive'),
          cooldownMs: any(named: 'cooldownMs'),
          usageLimit: any(named: 'usageLimit'),
          excludesFlows: any(named: 'excludesFlows'),
        ),
      ).thenAnswer(
        (_) async => const Flow(
          id: 'f1',
          templateId: 't1',
          name: 'Bienvenida',
          isActive: true,
          version: 4,
          cooldownMs: 5000,
          usageLimit: 3,
          excludesFlows: <String>['f2'],
        ),
      );

      final out = await repo.updateFlow(
        flowId: 'f1',
        version: 3,
        name: 'Bienvenida',
        isActive: true,
        cooldownMs: 5000,
        usageLimit: 3,
        excludesFlows: const <String>['f2'],
      );

      expect(out.id, 'f1');
      expect(out.version, 4);
      verify(
        () => ds.updateFlow(
          flowId: 'f1',
          version: 3,
          name: 'Bienvenida',
          isActive: true,
          cooldownMs: 5000,
          usageLimit: 3,
          excludesFlows: const <String>['f2'],
        ),
      ).called(1);
    });

    test('relanza FlowsConflictFailure sin envolver (CAS stale)', () async {
      when(
        () => ds.updateFlow(
          flowId: any(named: 'flowId'),
          version: any(named: 'version'),
          name: any(named: 'name'),
          isActive: any(named: 'isActive'),
          cooldownMs: any(named: 'cooldownMs'),
          usageLimit: any(named: 'usageLimit'),
          excludesFlows: any(named: 'excludesFlows'),
        ),
      ).thenThrow(const FlowsConflictFailure());

      await expectLater(
        () => repo.updateFlow(
          flowId: 'f1',
          version: 1,
          name: 'X',
          isActive: true,
          cooldownMs: 0,
          usageLimit: 0,
          excludesFlows: const <String>[],
        ),
        throwsA(isA<FlowsConflictFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.createStep', () {
    const newStep = fdom.Step(
      id: 's-new',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 2,
      content: 'Bienvenido',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 1500,
      jitterPct: 10,
      aiOnly: true,
    );

    test('delega 1:1 con todos los parámetros nombrados', () async {
      when(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 2,
          content: 'Bienvenido',
          mediaRef: '',
          delayMs: 1500,
          jitterPct: 10,
          aiOnly: true,
        ),
      ).thenAnswer((_) async => newStep);

      final out = await repo.createStep(
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 2,
        content: 'Bienvenido',
        mediaRef: '',
        delayMs: 1500,
        jitterPct: 10,
        aiOnly: true,
      );

      expect(out.id, 's-new');
      verify(
        () => ds.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 2,
          content: 'Bienvenido',
          mediaRef: '',
          delayMs: 1500,
          jitterPct: 10,
          aiOnly: true,
        ),
      ).called(1);
    });

    test('relanza FlowsInvalidStepFailure sin envolver', () async {
      when(
        () => ds.createStep(
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

      await expectLater(
        () => repo.createStep(
          flowId: 'f1',
          type: fdom.StepType.text,
          order: 0,
          content: '',
          mediaRef: '',
          delayMs: 0,
          jitterPct: 0,
          aiOnly: false,
        ),
        throwsA(isA<FlowsInvalidStepFailure>()),
      );
    });
  });

  group('FlowsRepositoryImpl.patchStep', () {
    const patched = fdom.Step(
      id: 's1',
      flowId: 'f1',
      type: fdom.StepType.text,
      order: 0,
      content: 'Edited',
      mediaRef: '',
      metadataJson: '{}',
      delayMs: 2000,
      jitterPct: 15,
      aiOnly: true,
    );

    test('delega 1:1 con campos opcionales', () async {
      when(
        () => ds.patchStep(
          stepId: 's1',
          content: 'Edited',
          delayMs: 2000,
          jitterPct: 15,
          aiOnly: true,
        ),
      ).thenAnswer((_) async => patched);

      final out = await repo.patchStep(
        stepId: 's1',
        content: 'Edited',
        delayMs: 2000,
        jitterPct: 15,
        aiOnly: true,
      );

      expect(out.id, 's1');
      verify(
        () => ds.patchStep(
          stepId: 's1',
          content: 'Edited',
          delayMs: 2000,
          jitterPct: 15,
          aiOnly: true,
        ),
      ).called(1);
    });

    test('omite parámetros null al delegar', () async {
      when(
        () => ds.patchStep(stepId: 's1', content: 'Solo content'),
      ).thenAnswer((_) async => patched);

      await repo.patchStep(stepId: 's1', content: 'Solo content');

      verify(
        () => ds.patchStep(stepId: 's1', content: 'Solo content'),
      ).called(1);
    });

    test('relanza FlowsStepNotFoundFailure', () async {
      when(
        () => ds.patchStep(
          stepId: any(named: 'stepId'),
          content: any(named: 'content'),
          delayMs: any(named: 'delayMs'),
          jitterPct: any(named: 'jitterPct'),
          aiOnly: any(named: 'aiOnly'),
        ),
      ).thenThrow(const FlowsStepNotFoundFailure());

      await expectLater(
        () => repo.patchStep(stepId: 'gone', content: 'X'),
        throwsA(isA<FlowsStepNotFoundFailure>()),
      );
    });
  });
}
