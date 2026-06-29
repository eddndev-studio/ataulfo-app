import 'package:ataulfo/features/ai_log/domain/entities/subagent_outcome_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubagentOutcomeEnvelope.tryParse', () {
    test('completed con summary y result → ambos poblados', () {
      const wire =
          '{"status":"completed","summary":"encontré 3 facturas","result":'
          '"detalle largo del subagente"}';
      final out = SubagentOutcomeEnvelope.tryParse(wire);
      expect(out, isNotNull);
      expect(out!.status, 'completed');
      expect(out.isCompleted, isTrue);
      expect(out.summary, 'encontré 3 facturas');
      expect(out.result, 'detalle largo del subagente');
      expect(out.reason, isEmpty);
    });

    test('completed con la clave summary AUSENTE (omitempty) → summary vacío '
        'sin perder result', () {
      // El backend marca summary,result,reason con omitempty: un campo vacío
      // NO viaja como "" sino que la clave desaparece. Es la forma real.
      const wire = '{"status":"completed","result":"solo el detalle"}';
      final out = SubagentOutcomeEnvelope.tryParse(wire);
      expect(out, isNotNull);
      expect(out!.summary, isEmpty);
      expect(out.result, 'solo el detalle');
    });

    test('completed con la clave result AUSENTE → result vacío sin perder '
        'summary', () {
      const wire = '{"status":"completed","summary":"hecho"}';
      final out = SubagentOutcomeEnvelope.tryParse(wire);
      expect(out, isNotNull);
      expect(out!.result, isEmpty);
      expect(out.summary, 'hecho');
    });

    test('completed sólo con status (ambas claves ausentes) → parsea, todo '
        'vacío salvo status', () {
      final out = SubagentOutcomeEnvelope.tryParse('{"status":"completed"}');
      expect(out, isNotNull);
      expect(out!.status, 'completed');
      expect(out.summary, isEmpty);
      expect(out.result, isEmpty);
      expect(out.reason, isEmpty);
    });

    test('failed con reason → reason poblado, summary/result vacíos', () {
      final out = SubagentOutcomeEnvelope.tryParse(
        '{"status":"failed","reason":"el proveedor falló"}',
      );
      expect(out, isNotNull);
      expect(out!.status, 'failed');
      expect(out.isCompleted, isFalse);
      expect(out.reason, 'el proveedor falló');
      expect(out.summary, isEmpty);
      expect(out.result, isEmpty);
    });

    test('blocked con reason → reason poblado', () {
      final out = SubagentOutcomeEnvelope.tryParse(
        '{"status":"blocked","reason":"invalid_input"}',
      );
      expect(out, isNotNull);
      expect(out!.status, 'blocked');
      expect(out.reason, 'invalid_input');
    });

    test('cadena no-JSON → null, no lanza', () {
      expect(SubagentOutcomeEnvelope.tryParse('texto plano'), isNull);
      expect(SubagentOutcomeEnvelope.tryParse(''), isNull);
    });

    test('JSON sin status (o status vacío) → null', () {
      expect(SubagentOutcomeEnvelope.tryParse('{"summary":"s"}'), isNull);
      expect(SubagentOutcomeEnvelope.tryParse('{"status":""}'), isNull);
    });

    test('JSON que no es objeto → null', () {
      expect(SubagentOutcomeEnvelope.tryParse('"completed"'), isNull);
    });

    test(
      'status fuera de {completed,failed,blocked} → null (degrada al blob)',
      () {
        // Coherente con el discriminador estricto de chat_analysis: un status
        // desconocido no se renderiza como tarjeta, cae al volcado crudo.
        expect(
          SubagentOutcomeEnvelope.tryParse('{"status":"timeout"}'),
          isNull,
        );
        expect(
          SubagentOutcomeEnvelope.tryParse('{"status":"pending"}'),
          isNull,
        );
      },
    );

    test('status válido pero campos mal tipados → null, no lanza', () {
      expect(
        SubagentOutcomeEnvelope.tryParse(
          '{"status":"completed","summary":123}',
        ),
        isNull,
      );
      expect(
        SubagentOutcomeEnvelope.tryParse('{"status":"failed","reason":42}'),
        isNull,
      );
    });
  });
}
