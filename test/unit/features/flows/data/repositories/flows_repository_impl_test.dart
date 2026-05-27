import 'package:agentic/features/flows/data/datasources/flows_datasource.dart';
import 'package:agentic/features/flows/data/repositories/flows_repository_impl.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart';
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
}
