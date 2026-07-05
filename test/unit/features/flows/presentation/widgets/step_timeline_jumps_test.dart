import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/widgets/step_timeline_jumps.dart';
import 'package:flutter_test/flutter_test.dart';

fdom.Step _text(String id, int order) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.text,
  order: order,
  content: 'msg $id',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

fdom.Step _ct(String id, int order, String metadataJson) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.conditionalTime,
  order: order,
  content: '',
  mediaRef: '',
  metadataJson: metadataJson,
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

String _ctJson(String matchId, String elseId) =>
    '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
    '"on_match_step_id":"$matchId","on_else_step_id":"$elseId"}';

void main() {
  group('stepTimelineJumps — saltos derivados de los condicionales', () {
    test('un CT sano emite dos saltos etiquetados hacia sus destinos', () {
      final steps = <fdom.Step>[
        _ct('ct', 0, _ctJson('a', 'b')),
        _text('a', 1),
        _text('b', 2),
      ];

      final jumps = stepTimelineJumps(steps);

      expect(jumps, hasLength(2));
      expect(jumps[0].from, 0);
      expect(jumps[0].to, 1);
      expect(jumps[0].label, 'si cumple');
      expect(jumps[1].from, 0);
      expect(jumps[1].to, 2);
      expect(jumps[1].label, 'si no');
    });

    test('destino colgante o hacia atrás NO emite salto (el resumen del '
        'CT ya lo marca en danger)', () {
      final steps = <fdom.Step>[
        _text('a', 0),
        // match apunta hacia atrás (a), else a un paso borrado (zz).
        _ct('ct', 1, _ctJson('a', 'zz')),
        _text('b', 2),
      ];

      expect(stepTimelineJumps(steps), isEmpty);
    });

    test('metadata ilegible o legacy posicional se omite en silencio', () {
      final steps = <fdom.Step>[
        _ct('ct1', 0, '{"tz":"","windows":[]}'),
        _ct(
          'ct2',
          1,
          '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
              '"on_match_order":2,"on_else_order":3}',
        ),
        _text('a', 2),
        _text('b', 3),
      ];

      expect(stepTimelineJumps(steps), isEmpty);
    });

    test('los índices son posiciones de LISTA, no orders del wire', () {
      // Lista con orders no contiguos (post-borrado fuera de banda).
      final steps = <fdom.Step>[
        _text('x', 2),
        _ct('ct', 5, _ctJson('a', 'b')),
        _text('a', 7),
        _text('b', 9),
      ];

      final jumps = stepTimelineJumps(steps);

      expect(jumps, hasLength(2));
      expect(jumps[0].from, 1);
      expect(jumps[0].to, 2);
      expect(jumps[1].to, 3);
    });
  });
}
