import 'package:ataulfo/features/ai_log/domain/ai_log_runs.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

AiLogEntry e(
  int id, {
  String runId = '',
  AiLogRole role = AiLogRole.assistant,
  String content = '',
}) => AiLogEntry(
  id: id,
  runId: runId,
  role: role,
  content: content,
  reasoning: '',
  toolCalls: const <AiToolCall>[],
  toolCallId: '',
  toolName: '',
  model: '',
  promptTokens: 0,
  completionTokens: 0,
  totalTokens: 0,
  createdAt: DateTime.utc(2026, 6, 12),
);

void main() {
  group('groupIntoRuns', () {
    test('agrupa por runId, corridas más recientes primero y entries '
        'cronológicas dentro de cada corrida', () {
      // El wire llega DESC (más reciente primero), como lo emite el backend.
      final desc = <AiLogEntry>[
        e(6, runId: 'r2', role: AiLogRole.assistant, content: 'adiós'),
        e(5, runId: 'r2', role: AiLogRole.user, content: 'chao'),
        e(4, runId: 'r1', role: AiLogRole.assistant, content: 'hola!'),
        e(3, runId: 'r1', role: AiLogRole.tool),
        e(2, runId: 'r1', role: AiLogRole.assistant),
        e(1, runId: 'r1', role: AiLogRole.user, content: 'hola'),
      ];

      final runs = groupIntoRuns(desc);

      expect(runs, hasLength(2));
      expect(runs.first.runId, 'r2');
      expect(runs.first.entries.map((x) => x.id), <int>[5, 6]);
      expect(runs.last.runId, 'r1');
      expect(runs.last.entries.map((x) => x.id), <int>[1, 2, 3, 4]);
    });

    test('filas legacy sin runId: cada turno user abre una corrida nueva', () {
      final desc = <AiLogEntry>[
        e(4, role: AiLogRole.assistant),
        e(3, role: AiLogRole.user),
        e(2, role: AiLogRole.assistant),
        e(1, role: AiLogRole.user),
      ];

      final runs = groupIntoRuns(desc);

      expect(runs, hasLength(2));
      expect(runs.first.entries.map((x) => x.id), <int>[3, 4]);
      expect(runs.last.entries.map((x) => x.id), <int>[1, 2]);
    });

    test('mezcla: el cambio de runId corta corrida aunque no haya user', () {
      final desc = <AiLogEntry>[
        e(3, runId: 'r2', role: AiLogRole.assistant),
        e(2, runId: 'r1', role: AiLogRole.assistant),
        e(1, runId: 'r1', role: AiLogRole.user),
      ];

      final runs = groupIntoRuns(desc);
      expect(runs, hasLength(2));
      expect(runs.first.runId, 'r2');
    });

    test('lista vacía ⇒ sin corridas', () {
      expect(groupIntoRuns(const <AiLogEntry>[]), isEmpty);
    });
  });
}
