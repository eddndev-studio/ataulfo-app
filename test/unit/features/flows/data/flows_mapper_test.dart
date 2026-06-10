import 'package:ataulfo/features/flows/data/dto/flow_dto.dart';
import 'package:ataulfo/features/flows/data/mappers/flows_mapper.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart';
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
          cooldownMs: 5000,
          usageLimit: 3,
          excludesFlows: <String>['f2', 'f3'],
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
            cooldownMs: 5000,
            usageLimit: 3,
            excludesFlows: <String>['f2', 'f3'],
          ),
        );
      },
    );
  });

  group('FlowsMapper.flowRespToEntity aiInvocable', () {
    test('propaga aiInvocable=true del DTO a la entity', () {
      const resp = FlowResp(
        id: 'f1',
        templateId: 't1',
        name: 'IA flow',
        isActive: true,
        aiInvocable: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );

      expect(FlowsMapper.flowRespToEntity(resp).aiInvocable, isTrue);
    });

    test('la entity equipara por aiInvocable (== y hashCode lo incluyen)', () {
      const a = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'n',
        isActive: true,
        aiInvocable: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      const b = Flow(
        id: 'f1',
        templateId: 't1',
        name: 'n',
        isActive: true,
        version: 1,
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );

      expect(a == b, isFalse);
    });
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
              cooldownMs: 0,
              usageLimit: 0,
              excludesFlows: <String>[],
            ),
            FlowResp(
              id: 'f2',
              templateId: 't1',
              name: 'B',
              isActive: false,
              version: 2,
              cooldownMs: 1000,
              usageLimit: 5,
              excludesFlows: <String>['f1'],
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
