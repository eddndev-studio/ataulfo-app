import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepType.fromWire', () {
    test('mapea el set completo de 8 valores UPPERCASE del wire', () {
      // Espejo del set del backend (domain/flow/step.go). Wire UPPERCASE
      // intencional — inconsistente con VarType (lowercase) pero refleja
      // el wire actual del backend. Si el backend cambia, fail-loud aquí.
      expect(fdom.StepType.fromWire('TEXT'), fdom.StepType.text);
      expect(fdom.StepType.fromWire('IMAGE'), fdom.StepType.image);
      expect(fdom.StepType.fromWire('VIDEO'), fdom.StepType.video);
      expect(fdom.StepType.fromWire('DOCUMENT'), fdom.StepType.document);
      expect(fdom.StepType.fromWire('AUDIO'), fdom.StepType.audio);
      expect(fdom.StepType.fromWire('PTT'), fdom.StepType.ptt);
      expect(fdom.StepType.fromWire('STICKER'), fdom.StepType.sticker);
      expect(
        fdom.StepType.fromWire('CONDITIONAL_TIME'),
        fdom.StepType.conditionalTime,
      );
    });

    test('tipo desconocido o casing distinto → ArgumentError (fail-loud)', () {
      expect(() => fdom.StepType.fromWire('text'), throwsArgumentError);
      expect(() => fdom.StepType.fromWire('Text'), throwsArgumentError);
      expect(() => fdom.StepType.fromWire('TOOL'), throwsArgumentError);
      expect(() => fdom.StepType.fromWire(''), throwsArgumentError);
    });
  });

  group('StepType.toWire (roundtrip con fromWire)', () {
    test('cada StepType serializa al token canónico UPPERCASE', () {
      for (final t in fdom.StepType.values) {
        expect(
          fdom.StepType.fromWire(t.toWire()),
          t,
          reason: 'roundtrip fallido para $t (wire=${t.toWire()})',
        );
      }
    });
  });

  group('Step value-equality', () {
    test('dos instancias con misma data son iguales', () {
      const a = fdom.Step(
        id: 's1',
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 0,
        content: 'Hola {{name}}',
        mediaRef: '',
        metadataJson: '{}',
        delayMs: 1000,
        jitterPct: 10,
        aiOnly: false,
      );
      const b = fdom.Step(
        id: 's1',
        flowId: 'f1',
        type: fdom.StepType.text,
        order: 0,
        content: 'Hola {{name}}',
        mediaRef: '',
        metadataJson: '{}',
        delayMs: 1000,
        jitterPct: 10,
        aiOnly: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('cambios en cualquier campo rompen equality', () {
      const base = fdom.Step(
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
      );
      expect(
        base,
        isNot(equals(base.copyWith(content: 'Adiós'))),
        reason: 'content',
      );
      expect(
        base,
        isNot(equals(base.copyWith(order: 1))),
        reason: 'order',
      );
      expect(
        base,
        isNot(equals(base.copyWith(type: fdom.StepType.image))),
        reason: 'type',
      );
      expect(
        base,
        isNot(equals(base.copyWith(delayMs: 500))),
        reason: 'delayMs',
      );
      expect(
        base,
        isNot(equals(base.copyWith(jitterPct: 20))),
        reason: 'jitterPct',
      );
      expect(
        base,
        isNot(equals(base.copyWith(aiOnly: true))),
        reason: 'aiOnly',
      );
    });
  });
}
