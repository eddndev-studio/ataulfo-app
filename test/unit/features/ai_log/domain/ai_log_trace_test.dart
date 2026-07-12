import 'package:ataulfo/features/ai_log/domain/ai_log_trace.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_run_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

AiLogEntry e(
  int id, {
  String runId = 'r1',
  AiLogRole role = AiLogRole.assistant,
  String content = '',
  String reasoning = '',
  List<AiToolCall> toolCalls = const <AiToolCall>[],
  String toolCallId = '',
  String toolName = '',
  DateTime? at,
}) => AiLogEntry(
  id: id,
  runId: runId,
  role: role,
  content: content,
  reasoning: reasoning,
  toolCalls: toolCalls,
  toolCallId: toolCallId,
  toolName: toolName,
  model: '',
  promptTokens: 0,
  completionTokens: 0,
  totalTokens: 0,
  createdAt: at ?? DateTime.utc(2026, 7, 1, 10),
);

void main() {
  group('buildRunTrace — gramática PERSISTIDA de una corrida', () {
    test('user fuera de la traza; thinking con texto; tool con título humano '
        'y su entry alineada por nodo', () {
      final view = buildRunTrace(<AiLogEntry>[
        e(1, role: AiLogRole.user, content: '¿tienen horario?'),
        e(
          2,
          reasoning: 'el doc dice 9-18',
          toolCalls: const <AiToolCall>[
            AiToolCall(id: 'c1', name: 'read_doc', argumentsJson: '{"n":1}'),
          ],
        ),
        e(3, role: AiLogRole.tool, toolCallId: 'c1', toolName: 'read_doc'),
        e(4, content: 'Abrimos 9-18.'),
      ]);

      expect(view.users.single.content, '¿tienen horario?');
      expect(view.responses.single.content, 'Abrimos 9-18.');
      expect(view.trace.nodos, hasLength(2));
      expect(view.trace.nodos[0].kind, TraceNodeKind.thinking);
      expect(view.trace.nodos[0].detalle, 'el doc dice 9-18');
      expect(view.trace.nodos[1].kind, TraceNodeKind.tool);
      expect(view.trace.nodos[1].titulo, 'Leyó un documento');
      expect(view.nodeEntries[1].id, 3);
      expect(view.argsByCallId['c1'], '{"n":1}');
    });

    test('la narración a MITAD de corrida (content + tool_calls en la misma '
        'fila) es un paso del proceso, no una burbuja de respuesta', () {
      final view = buildRunTrace(<AiLogEntry>[
        e(1, role: AiLogRole.user, content: 'revisa'),
        e(
          2,
          content: 'Déjame revisar el catálogo…',
          toolCalls: const <AiToolCall>[
            AiToolCall(id: 'c1', name: 'read_doc', argumentsJson: '{}'),
          ],
        ),
        e(3, role: AiLogRole.tool, toolCallId: 'c1', toolName: 'read_doc'),
        e(4, content: 'Listo: 3 productos.'),
      ]);
      // Solo la respuesta final (sin tool_calls) es burbuja del Bot.
      expect(view.responses.single.content, 'Listo: 3 productos.');
      final narracion = view.trace.nodos.firstWhere(
        (n) => n.titulo == 'Narración de la corrida',
      );
      expect(narracion.detalle, 'Déjame revisar el catálogo…');
      // La alineación nodo↔entry sobrevive a la inserción.
      final idx = view.trace.nodos.indexOf(narracion);
      expect(view.nodeEntries[idx].id, 2);
    });

    test('system es la voz del motor: nodo atenuado con su texto', () {
      final view = buildRunTrace(<AiLogEntry>[
        e(1, role: AiLogRole.system, content: 'usa done'),
      ]);
      expect(view.trace.nodos.single.titulo, 'Aviso del sistema');
      expect(view.trace.nodos.single.detalle, 'usa done');
    });

    test('duración = primera→última fila; una sola fila no mide', () {
      final view = buildRunTrace(<AiLogEntry>[
        e(1, role: AiLogRole.user, at: DateTime.utc(2026, 7, 1, 10, 0, 0)),
        e(2, content: 'ok', at: DateTime.utc(2026, 7, 1, 10, 0, 42)),
      ]);
      expect(view.trace.duracion, const Duration(seconds: 42));
      final single = buildRunTrace(<AiLogEntry>[e(1, content: 'ok')]);
      expect(single.trace.duracion, isNull);
    });

    test('parcial (frontera de paginación) viaja a la traza', () {
      final view = buildRunTrace(<AiLogEntry>[
        e(2, role: AiLogRole.tool, toolName: 'read_doc'),
      ], parcial: true);
      expect(view.trace.parcial, isTrue);
    });
  });

  group('runOutcomeNode — el desenlace del drill', () {
    final ok = AiRunOutcome(
      status: 'COMPLETED',
      error: '',
      iterations: 3,
      tokensIn: 100,
      tokensOut: 40,
      startedAt: DateTime.utc(2026, 7, 1, 10),
      endedAt: DateTime.utc(2026, 7, 1, 10, 0, 42),
    );

    test('✓ «Corrida completada» con duración SIEMPRE aproximada («~»)', () {
      final n = runOutcomeNode(ok);
      expect(n.kind, TraceNodeKind.respuesta);
      expect(n.titulo, 'Corrida completada · ~42s');
      expect(n.isError, isFalse);
    });

    test('✗ el fallo SIEMPRE con el copy es-MX del core, jamás el crudo', () {
      final n = runOutcomeNode(
        AiRunOutcome(
          status: 'FAILED',
          error: 'context deadline exceeded',
          iterations: 9,
          tokensIn: 0,
          tokensOut: 0,
          startedAt: DateTime.utc(2026, 7, 1, 10),
          endedAt: DateTime.utc(2026, 7, 1, 10, 3),
        ),
      );
      expect(n.kind, TraceNodeKind.fallo);
      expect(n.isError, isTrue);
      // El punto final del copy se recorta al componer con la duración.
      expect(n.titulo, 'La corrida excedió el tiempo límite · ~3m');
      expect(n.titulo.contains('deadline'), isFalse);
    });

    test('relojes raros (duración no positiva) ⇒ sin sufijo de duración', () {
      final n = runOutcomeNode(
        AiRunOutcome(
          status: 'COMPLETED',
          error: '',
          iterations: 1,
          tokensIn: 0,
          tokensOut: 0,
          startedAt: DateTime.utc(2026, 7, 1, 10),
          endedAt: DateTime.utc(2026, 7, 1, 10),
        ),
      );
      expect(n.titulo, 'Corrida completada');
    });

    test('startedAt en el zero time de Go (started_at NULL en ai_runs) '
        '⇒ sin duración absurda', () {
      final n = runOutcomeNode(
        AiRunOutcome(
          status: 'COMPLETED',
          error: '',
          iterations: 1,
          tokensIn: 0,
          tokensOut: 0,
          startedAt: DateTime.utc(1),
          endedAt: DateTime.utc(2026, 7, 1, 10),
        ),
      );
      expect(n.titulo, 'Corrida completada');
    });
  });

  group('approxDurationLabel (core)', () {
    test('segundos, minutos y horas, siempre con «~»', () {
      expect(approxDurationLabel(const Duration(seconds: 42)), '~42s');
      expect(
        approxDurationLabel(const Duration(minutes: 3, seconds: 5)),
        '~3m',
      );
      expect(approxDurationLabel(const Duration(hours: 2, minutes: 10)), '~2h');
    });
  });
}
