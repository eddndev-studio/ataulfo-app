import 'package:agentic/features/flows/data/datasources/flows_datasource.dart';
import 'package:agentic/features/flows/data/repositories/flows_repository_impl.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements FlowsDatasource {}

void main() {
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
}
