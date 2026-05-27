import 'package:agentic/features/flows/data/dto/flow_dto.dart';
import 'package:agentic/features/flows/data/mappers/flows_mapper.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowsMapper.flowRespToEntity', () {
    test(
      'traduce el DTO al shape de la entity preservando todos los campos',
      () {
        const resp = FlowResp(
          id: 'f1',
          templateId: 't1',
          name: 'Bienvenida',
          isActive: true,
          version: 5,
        );

        final entity = FlowsMapper.flowRespToEntity(resp);

        expect(
          entity,
          const Flow(
            id: 'f1',
            templateId: 't1',
            name: 'Bienvenida',
            isActive: true,
            version: 5,
          ),
        );
      },
    );
  });

  group('FlowsMapper.listToFlows', () {
    test(
      'traduce el wrapper a List<Flow> preservando el orden del backend',
      () {
        const list = ListFlowsResp(
          items: <FlowResp>[
            FlowResp(
              id: 'f1',
              templateId: 't1',
              name: 'A',
              isActive: true,
              version: 1,
            ),
            FlowResp(
              id: 'f2',
              templateId: 't1',
              name: 'B',
              isActive: false,
              version: 2,
            ),
          ],
        );

        final flows = FlowsMapper.listToFlows(list);

        expect(flows, hasLength(2));
        expect(flows[0].id, 'f1');
        expect(flows[1].id, 'f2');
        expect(flows[1].isActive, isFalse);
      },
    );
  });
}
