import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepType.fromWire', () {
    test('mapea el set completo de valores UPPERCASE del wire', () {
      // Espejo del set del backend (domain/flow/step.go). Wire UPPERCASE
      // intencional — refleja el wire actual del backend.
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
      expect(fdom.StepType.fromWire('LABEL'), fdom.StepType.label);
    });

    test('token desconocido → StepType.unsupported (degrada, no crashea)', () {
      // Degradación elegante: un tipo de paso que esta versión de la app no
      // conoce (uno futuro del backend, o casing distinto) NO rompe la carga
      // del flujo — se mapea a `unsupported` para renderizarse como "actualiza
      // la app" sin perder los demás pasos. Cambia la política fail-loud SOLO
      // para tokens de StepType (no para el resto del contrato).
      expect(fdom.StepType.fromWire('FUTURE_TYPE'), fdom.StepType.unsupported);
      expect(fdom.StepType.fromWire('TOOL'), fdom.StepType.unsupported);
      expect(fdom.StepType.fromWire('text'), fdom.StepType.unsupported);
      expect(fdom.StepType.fromWire(''), fdom.StepType.unsupported);
    });
  });

  group('StepType.toWire', () {
    test('cada StepType soportado roundtrip-ea con fromWire', () {
      for (final t in fdom.StepType.values) {
        if (t == fdom.StepType.unsupported) continue; // centinela sin token
        expect(
          fdom.StepType.fromWire(t.toWire()),
          t,
          reason: 'roundtrip fallido para $t (wire=${t.toWire()})',
        );
      }
    });

    test('unsupported no tiene token de wire → toWire lanza', () {
      // unsupported nunca se serializa: no se puede crear (no está en el
      // picker) ni re-serializar su tipo (el reorder es PATCH de order). El
      // throw es defensivo: marca un bug si algún path lo intentara.
      expect(() => fdom.StepType.unsupported.toWire(), throwsArgumentError);
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
      expect(base, isNot(equals(base.copyWith(order: 1))), reason: 'order');
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
