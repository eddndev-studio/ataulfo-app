import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/widgets/step_reorder_rules.dart';
import 'package:flutter_test/flutter_test.dart';

fdom.Step _text(String id) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.text,
  order: 0,
  content: 'msg $id',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

fdom.Step _ct(String id, {required String metadataJson}) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.conditionalTime,
  order: 0,
  content: '',
  mediaRef: '',
  metadataJson: metadataJson,
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

String _idRefs(String matchId, String elseId) =>
    '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
    '"on_match_step_id":"$matchId","on_else_step_id":"$elseId"}';

void main() {
  group('conditionalTargetsStayForward', () {
    test('sin condicionales el orden siempre es válido', () {
      final ordered = <fdom.Step>[_text('a'), _text('b'), _text('c')];
      expect(conditionalTargetsStayForward(ordered), isTrue);
    });

    test('condicional ANTES de sus dos destinos es válido', () {
      final ordered = <fdom.Step>[
        _ct('ct', metadataJson: _idRefs('a', 'b')),
        _text('a'),
        _text('b'),
      ];
      expect(conditionalTargetsStayForward(ordered), isTrue);
    });

    test('condicional DESPUÉS de su destino de match es inválido', () {
      final ordered = <fdom.Step>[
        _text('a'),
        _ct('ct', metadataJson: _idRefs('a', 'b')),
        _text('b'),
      ];
      expect(conditionalTargetsStayForward(ordered), isFalse);
    });

    test('condicional DESPUÉS de su destino de else es inválido', () {
      final ordered = <fdom.Step>[
        _text('b'),
        _ct('ct', metadataJson: _idRefs('a', 'b')),
        _text('a'),
      ];
      expect(conditionalTargetsStayForward(ordered), isFalse);
    });

    test('condicional movido al final (ambos destinos atrás) es inválido', () {
      final ordered = <fdom.Step>[
        _text('a'),
        _text('b'),
        _ct('ct', metadataJson: _idRefs('a', 'b')),
      ];
      expect(conditionalTargetsStayForward(ordered), isFalse);
    });

    test('un destino colgante (paso borrado) se omite — el aviso de la '
        'card y el backend cubren ese caso', () {
      final ordered = <fdom.Step>[
        _text('a'),
        _ct('ct', metadataJson: _idRefs('ghost', 'b')),
        _text('b'),
      ];
      expect(conditionalTargetsStayForward(ordered), isTrue);
    });

    test('metadata ilegible se omite (el backend es la red final)', () {
      final ordered = <fdom.Step>[
        _text('a'),
        _ct('ct', metadataJson: '{no-json'),
      ];
      expect(conditionalTargetsStayForward(ordered), isTrue);
    });

    test('fila legacy posicional (sin ids) se omite', () {
      final ordered = <fdom.Step>[
        _text('a'),
        _ct(
          'ct',
          metadataJson:
              '{"tz":"UTC","windows":[{"days":[1],"from":"09:00",'
              '"to":"18:00"}],"on_match_order":0,"on_else_order":1}',
        ),
      ];
      expect(conditionalTargetsStayForward(ordered), isTrue);
    });

    test('con varios condicionales basta uno violado para rechazar', () {
      final ordered = <fdom.Step>[
        _ct('ct1', metadataJson: _idRefs('a', 'b')),
        _text('a'),
        _text('b'),
        _ct('ct2', metadataJson: _idRefs('a', 'c')),
        _text('c'),
      ];
      expect(conditionalTargetsStayForward(ordered), isFalse);
    });
  });
}
