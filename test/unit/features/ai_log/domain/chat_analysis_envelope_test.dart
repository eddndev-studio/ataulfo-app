import 'package:ataulfo/features/ai_log/domain/entities/chat_analysis_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatAnalysisEnvelope.tryParse', () {
    test('parsea la cadena exacta del wire (un solo jsonDecode)', () {
      // Forma real que emite analyze_chat: facts/timeline SIEMPRE arrays (sin
      // omitempty en el backend); content es el resultado pelado, no envuelto.
      const wire =
          '{"kind":"chat_analysis","summary":"el cliente pregunta por el '
          'horario","facts":["es mayorista","prefiere la tarde"],'
          '"sentiment":"neutral","timeline":[{"at":"10:00","event":"saluda"}],'
          '"truncated":false}';

      final env = ChatAnalysisEnvelope.tryParse(wire);

      expect(env, isNotNull);
      expect(env!.summary, 'el cliente pregunta por el horario');
      expect(env.facts, <String>['es mayorista', 'prefiere la tarde']);
      expect(env.sentiment, 'neutral');
      expect(env.timeline, hasLength(1));
      expect(env.timeline.first.at, '10:00');
      expect(env.timeline.first.event, 'saluda');
      expect(env.truncated, isFalse);
    });

    test('truncated=true se preserva', () {
      const wire =
          '{"kind":"chat_analysis","summary":"s","facts":[],"sentiment":"",'
          '"timeline":[],"truncated":true}';
      expect(ChatAnalysisEnvelope.tryParse(wire)!.truncated, isTrue);
    });

    test('facts y timeline presentes pero vacíos → listas vacías, no null', () {
      // El backend coacciona nil→[] (forma estable), así que la forma real con
      // "nada" es present-but-empty, nunca ausente.
      const wire =
          '{"kind":"chat_analysis","summary":"s","facts":[],"sentiment":"pos",'
          '"timeline":[],"truncated":false}';
      final env = ChatAnalysisEnvelope.tryParse(wire);
      expect(env, isNotNull);
      expect(env!.facts, isEmpty);
      expect(env.timeline, isEmpty);
    });

    test('cadena no-JSON (blob libre) → null, no lanza', () {
      expect(ChatAnalysisEnvelope.tryParse('un texto cualquiera'), isNull);
      expect(ChatAnalysisEnvelope.tryParse(''), isNull);
    });

    test('JSON válido sin kind o con otro kind → null', () {
      expect(
        ChatAnalysisEnvelope.tryParse('{"summary":"s","facts":[]}'),
        isNull,
      );
      expect(
        ChatAnalysisEnvelope.tryParse('{"kind":"otra_cosa","summary":"s"}'),
        isNull,
      );
    });

    test('JSON que no es objeto (array) → null', () {
      expect(ChatAnalysisEnvelope.tryParse('[1,2,3]'), isNull);
    });

    test('estructura correcta pero campos mal tipados → null, no lanza', () {
      // valid-JSON-wrong-shape debe degradar al blob, no crashear el render.
      expect(
        ChatAnalysisEnvelope.tryParse(
          '{"kind":"chat_analysis","summary":123,"facts":[],"sentiment":"",'
          '"timeline":[],"truncated":false}',
        ),
        isNull,
      );
      expect(
        ChatAnalysisEnvelope.tryParse(
          '{"kind":"chat_analysis","summary":"s","facts":[],"sentiment":7,'
          '"timeline":[],"truncated":false}',
        ),
        isNull,
      );
      expect(
        ChatAnalysisEnvelope.tryParse(
          '{"kind":"chat_analysis","summary":"s","facts":[],"sentiment":"",'
          '"timeline":[],"truncated":"sí"}',
        ),
        isNull,
      );
    });
  });
}
