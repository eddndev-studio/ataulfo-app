import 'package:agentic/features/flows/data/dto/step_dto.dart';
import 'package:agentic/features/flows/data/mappers/steps_mapper.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepsMapper.stepRespToEntity', () {
    test(
      'traduce el DTO al shape de la entity preservando todos los campos',
      () {
        const resp = StepResp(
          id: 's1',
          flowId: 'f1',
          type: 'IMAGE',
          order: 2,
          content: 'caption',
          mediaRef: 'https://example.com/x.png',
          metadataJson: '{"alt":"foo"}',
          delayMs: 1500,
          jitterPct: 15,
          aiOnly: true,
        );

        final entity = StepsMapper.stepRespToEntity(resp);

        expect(
          entity,
          const fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 2,
            content: 'caption',
            mediaRef: 'https://example.com/x.png',
            metadataJson: '{"alt":"foo"}',
            delayMs: 1500,
            jitterPct: 15,
            aiOnly: true,
          ),
        );
      },
    );

    test('type desconocido propaga ArgumentError (fail-loud)', () {
      const resp = StepResp(
        id: 's1',
        flowId: 'f1',
        type: 'TOOL',
        order: 0,
        content: '',
        mediaRef: '',
        metadataJson: '{}',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      );
      expect(() => StepsMapper.stepRespToEntity(resp), throwsArgumentError);
    });
  });

  group('StepsMapper.listToSteps', () {
    test('traduce {items:[...]} preservando el orden del backend', () {
      const list = ListStepsResp(
        items: <StepResp>[
          StepResp(
            id: 's1',
            flowId: 'f1',
            type: 'TEXT',
            order: 0,
            content: 'A',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          StepResp(
            id: 's2',
            flowId: 'f1',
            type: 'AUDIO',
            order: 1,
            content: '',
            mediaRef: 'ref',
            metadataJson: '{}',
            delayMs: 250,
            jitterPct: 0,
            aiOnly: false,
          ),
        ],
      );

      final steps = StepsMapper.listToSteps(list);

      expect(steps, hasLength(2));
      expect(steps[0].order, 0);
      expect(steps[0].type, fdom.StepType.text);
      expect(steps[1].order, 1);
      expect(steps[1].type, fdom.StepType.audio);
    });
  });
}
