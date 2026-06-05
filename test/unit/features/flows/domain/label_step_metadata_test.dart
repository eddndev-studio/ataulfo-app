import 'package:ataulfo/features/flows/domain/entities/label_step_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LabelStepMetadata.fromJsonString', () {
    test('parsea {label_id, action} válido (ADD/REMOVE)', () {
      final add = LabelStepMetadata.fromJsonString(
        '{"label_id":"lbl-1","action":"ADD"}',
      );
      expect(add.labelId, 'lbl-1');
      expect(add.action, LabelStepAction.add);

      final remove = LabelStepMetadata.fromJsonString(
        '{"label_id":"lbl-1","action":"REMOVE"}',
      );
      expect(remove.action, LabelStepAction.remove);
    });

    test('shapes inválidos lanzan FormatException', () {
      const cases = <String>[
        '{', // json malformado
        '{"action":"ADD"}', // label_id ausente
        '{"label_id":"","action":"ADD"}', // label_id vacío
        '{"label_id":"x"}', // action ausente
        '{"label_id":"x","action":"TOGGLE"}', // action fuera de ADD|REMOVE
        '{"label_id":"x","action":"add"}', // casing distinto
        '[]', // no es objeto
      ];
      for (final raw in cases) {
        expect(
          () => LabelStepMetadata.fromJsonString(raw),
          throwsFormatException,
          reason: raw,
        );
      }
    });
  });

  group('LabelStepMetadata.toJsonString', () {
    test('roundtrip con fromJsonString', () {
      const md = LabelStepMetadata(
        labelId: 'lbl-vip',
        action: LabelStepAction.remove,
      );
      expect(LabelStepMetadata.fromJsonString(md.toJsonString()), md);
    });

    test('emite snake_case + tokens UPPERCASE', () {
      const md = LabelStepMetadata(
        labelId: 'lbl-1',
        action: LabelStepAction.add,
      );
      expect(md.toJsonString(), '{"label_id":"lbl-1","action":"ADD"}');
    });
  });

  group('value-equality', () {
    test('misma data ⇒ iguales; distinta ⇒ distintas', () {
      const a = LabelStepMetadata(labelId: 'x', action: LabelStepAction.add);
      const b = LabelStepMetadata(labelId: 'x', action: LabelStepAction.add);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          equals(
            const LabelStepMetadata(labelId: 'y', action: LabelStepAction.add),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            const LabelStepMetadata(
              labelId: 'x',
              action: LabelStepAction.remove,
            ),
          ),
        ),
      );
    });
  });
}
