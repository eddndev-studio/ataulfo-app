import 'package:ataulfo/features/platform_agent/data/dto/pa_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> convJson({String id = 'c1'}) => <String, dynamic>{
  'id': id,
  'org_id': 'org1',
  'operator_id': 'u1',
  'title': 'Operación',
  'created_at': '2026-06-10T10:00:00.000Z',
  'updated_at': '2026-06-10T11:00:00.000Z',
};

Map<String, dynamic> msgJson({
  String role = 'assistant',
  String content = 'listo',
  Object? toolCalls,
  Object? toolResults,
}) => <String, dynamic>{
  'id': 'm1',
  'conversation_id': 'c1',
  'role': role,
  'content': content,
  'tool_calls': ?toolCalls,
  'tool_results': ?toolResults,
  'created_at': '2026-06-10T10:00:01.000Z',
};

Map<String, dynamic> progJson({
  String kind = 'tool',
  String conversationId = 'c1',
  Object? toolName = 'list_bots',
}) => <String, dynamic>{
  'runId': 'r1',
  'conversationId': conversationId,
  'iteration': 2,
  'kind': kind,
  'model': 'gemini-3.1-pro',
  'toolName': ?toolName,
  'at': '2026-06-10T10:00:02.000Z',
};

void main() {
  group('PaConversationDto', () {
    test('parsea snake_case canónico', () {
      final c = PaConversationDto.fromJson(convJson()).toEntity();
      expect(c.id, 'c1');
      expect(c.title, 'Operación');
      expect(c.createdAt.isUtc, isTrue);
    });

    test('title ausente degrada a vacío (tolerante)', () {
      final json = convJson()..remove('title');
      expect(PaConversationDto.fromJson(json).toEntity().title, '');
    });

    test('id no-string ⇒ FormatException (canónico falla loud)', () {
      final json = convJson()..['id'] = 42;
      expect(() => PaConversationDto.fromJson(json), throwsFormatException);
    });
  });

  group('PaMessageDto', () {
    test('conserva tool_calls/tool_results CRUDO como string', () {
      final m = PaMessageDto.fromJson(
        msgJson(
          role: 'tool',
          content: '',
          toolResults: <String, dynamic>{'toolName': 'set_bot_ai_disabled'},
        ),
      ).toEntity();
      expect(m.role, 'tool');
      expect(m.isTool, isTrue);
      expect(m.toolResultsRaw, isNotNull);
      expect(m.toolResultsRaw, contains('set_bot_ai_disabled'));
    });

    test('content ausente en assistant ⇒ vacío (puro tool_calls)', () {
      final json = msgJson()..remove('content');
      expect(PaMessageDto.fromJson(json).toEntity().content, '');
    });

    test('role no-string ⇒ FormatException', () {
      final json = msgJson()..['role'] = 7;
      expect(() => PaMessageDto.fromJson(json), throwsFormatException);
    });
  });

  group('PaProgressEventDto', () {
    test('parsea el paWire del SSE', () {
      final e = PaProgressEventDto.fromJson(progJson()).toEntity();
      expect(e.kind, 'tool');
      expect(e.conversationId, 'c1');
      expect(e.toolName, 'list_bots');
      expect(e.iteration, 2);
      expect(e.isTool, isTrue);
      expect(e.isTerminal, isFalse);
    });

    test('kind=completed ⇒ terminal; toolName ausente degrada a vacío', () {
      final e = PaProgressEventDto.fromJson(
        progJson(kind: 'completed', toolName: null),
      ).toEntity();
      expect(e.isCompleted, isTrue);
      expect(e.isTerminal, isTrue);
      expect(e.toolName, '');
    });

    test('kind=failed ⇒ terminal', () {
      final e = PaProgressEventDto.fromJson(
        progJson(kind: 'failed', toolName: null),
      ).toEntity();
      expect(e.isFailed, isTrue);
      expect(e.isTerminal, isTrue);
    });

    test('kind ausente ⇒ FormatException (canónico)', () {
      final json = progJson()..remove('kind');
      expect(() => PaProgressEventDto.fromJson(json), throwsFormatException);
    });
  });
}
