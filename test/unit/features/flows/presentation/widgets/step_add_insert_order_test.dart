import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/widgets/step_edit_support.dart';
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

StepDraft _draft({String? ctMetadataJson}) => StepDraft(
  content: 'hola',
  mediaRef: '',
  isConditionalTime: ctMetadataJson != null,
  isLabel: false,
  isMultimedia: false,
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
  manualOnly: false,
  ctMetadataJson: ctMetadataJson,
  ctInitial: null,
  labelMetadataJson: null,
  labelInitial: null,
  mediaMetadataJson: null,
);

/// Metadata CT válida apuntando a los pasos `a` (match) y `b` (else).
const String _ctJson =
    '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
    '"on_match_step_id":"a","on_else_step_id":"b"}';

void main() {
  final steps = <fdom.Step>[_text('a', 0), _text('b', 1), _text('c', 2)];

  group('stepAddEvent — inserción posicional del alta genérica', () {
    test('sin insertAt el alta genérica conserva el append clásico '
        '(order null: el bloc resuelve la longitud del snapshot)', () {
      final ev = stepAddEvent(fdom.StepType.text, _draft(), steps);
      expect(ev.order, isNull);
    });

    test('insertAt viaja como order del alta genérica: el paso nuevo '
        'ocupa esa posición y el backend desplaza los siguientes', () {
      final ev = stepAddEvent(fdom.StepType.text, _draft(), steps, insertAt: 1);
      expect(ev.order, 1);
    });

    test('el condicional SIN insertAt conserva su auto-inserción antes '
        'del destino más temprano', () {
      final ev = stepAddEvent(
        fdom.StepType.conditionalTime,
        _draft(ctMetadataJson: _ctJson),
        steps,
      );
      expect(ev.order, 0);
    });

    test('el condicional CON insertAt respeta la posición pedida cuando '
        'queda antes de sus destinos', () {
      // Destino más temprano: `a` en 0 ⇒ el único insertAt válido es 0.
      final tailSteps = <fdom.Step>[
        _text('x', 0),
        _text('a', 1),
        _text('b', 2),
      ];
      final ev = stepAddEvent(
        fdom.StepType.conditionalTime,
        _draft(ctMetadataJson: _ctJson),
        tailSteps,
        insertAt: 0,
      );
      expect(ev.order, 0);
    });

    test('el condicional CON insertAt DESPUÉS de un destino se acota a la '
        'auto-inserción — forward-only por construcción, no 422', () {
      final tailSteps = <fdom.Step>[
        _text('x', 0),
        _text('a', 1),
        _text('b', 2),
      ];
      final ev = stepAddEvent(
        fdom.StepType.conditionalTime,
        _draft(ctMetadataJson: _ctJson),
        tailSteps,
        insertAt: 2,
      );
      expect(ev.order, 1);
    });
  });
}
