import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_progress.dart';
import 'package:ataulfo/features/platform_agent/domain/pa_trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaProgressEvent _ev(
  String kind, {
  String toolName = '',
  bool toolError = false,
  String error = '',
  DateTime? at,
}) => PaProgressEvent(
  kind: kind,
  conversationId: 'c1',
  at: at ?? DateTime.utc(2026, 1, 1),
  toolName: toolName,
  toolError: toolError,
  error: error,
);

PaMessage _msg(
  String role, {
  String content = '',
  String thinking = '',
  String? toolResultsRaw,
  String? toolCallsRaw,
  DateTime? at,
}) => PaMessage(
  id: '${role}_${content.hashCode}_${thinking.hashCode}',
  conversationId: 'c1',
  role: role,
  content: content,
  thinking: thinking,
  toolResultsRaw: toolResultsRaw,
  toolCallsRaw: toolCallsRaw,
  createdAt: at ?? DateTime.utc(2026, 1, 1),
);

String _toolRaw(
  String tool, {
  String? errorKind,
  List<Map<String, String>> changed = const [],
}) {
  final inner = <String, Object>{};
  if (errorKind != null) inner['error_kind'] = errorKind;
  if (changed.isNotEmpty) inner['changed'] = changed;
  return '{"tool_name":"$tool","content":${_json(inner)}}';
}

// Serializa el content interno como un string JSON doble-codificado (como el
// wire real): un string cuyo valor es JSON.
String _json(Map<String, Object> m) {
  final buf = StringBuffer('"{');
  final parts = <String>[];
  m.forEach((k, v) {
    if (v is String) {
      parts.add('\\"$k\\":\\"$v\\"');
    } else if (v is List) {
      final items = v
          .cast<Map<String, String>>()
          .map(
            (c) =>
                '{\\"field\\":\\"${c['field']}\\",\\"from\\":\\"${c['from']}\\",\\"to\\":\\"${c['to']}\\"}',
          )
          .join(',');
      parts.add('\\"$k\\":[$items]');
    }
  });
  buf.write(parts.join(','));
  buf.write('}"');
  return buf.toString();
}

void main() {
  group('nodeFromProgress (gramática viva)', () {
    test('thinking ⇒ nodo etiqueta sin texto', () {
      final n = nodeFromProgress(_ev('thinking'))!;
      expect(n.kind, TraceNodeKind.thinking);
      expect(n.titulo, 'Pensando…');
      expect(n.detalle, isNull);
    });

    test('tool ⇒ nodo con el título humano y el ícono del tool', () {
      final n = nodeFromProgress(_ev('tool', toolName: 'list_bots'))!;
      expect(n.kind, TraceNodeKind.tool);
      expect(n.titulo, 'Consultó los bots');
      expect(n.icon, Icons.smart_toy_outlined);
      expect(n.isError, isFalse);
    });

    test('tool sin nombre ⇒ «Trabajando…»', () {
      expect(nodeFromProgress(_ev('tool'))!.titulo, 'Trabajando…');
    });

    test('toolError marca el nodo como error', () {
      expect(
        nodeFromProgress(
          _ev('tool', toolName: 'delete_flow', toolError: true),
        )!.isError,
        isTrue,
      );
    });

    test('completed y failed ⇒ null (el cierre lo da el POST)', () {
      expect(nodeFromProgress(_ev('completed')), isNull);
      expect(
        nodeFromProgress(_ev('failed', error: 'context deadline exceeded')),
        isNull,
      );
    });
  });

  group('liveTrace', () {
    test('mapea eventos a nodos y colapsa thinking adyacente', () {
      final t = liveTrace(<PaProgressEvent>[
        _ev('thinking'),
        _ev('thinking'),
        _ev('tool', toolName: 'list_bots'),
        _ev('thinking'),
        _ev('tool', toolName: 'get_flow'),
      ]);
      expect(t.nodos.map((n) => n.kind).toList(), <TraceNodeKind>[
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
      ]);
      expect(t.parcial, isFalse);
    });

    test('un failed antes del cierre aporta la causa es-MX al resumen', () {
      final t = liveTrace(<PaProgressEvent>[
        _ev('thinking'),
        _ev('failed', error: 'context deadline exceeded'),
      ]);
      expect(t.fallo, 'La corrida excedió el tiempo límite.');
      expect(summarizeTrace(t), 'Falló: La corrida excedió el tiempo límite.');
    });

    test('duración = del primer evento al cierre', () {
      final t = liveTrace(<PaProgressEvent>[
        _ev('thinking', at: DateTime.utc(2026, 1, 1, 0, 0, 0)),
      ], closedAt: DateTime.utc(2026, 1, 1, 0, 0, 5));
      expect(t.duracion, const Duration(seconds: 5));
    });
  });

  group('traceFromMessages (gramática persistida)', () {
    test('agrupa un turno completo: user, proceso y respuesta final', () {
      final turns = traceFromMessages(<PaMessage>[
        _msg('user', content: 'Hola', at: DateTime.utc(2026, 1, 1, 0, 0, 0)),
        _msg(
          'assistant',
          thinking: 'Debo mirar los bots',
          toolCallsRaw: '[]',
          at: DateTime.utc(2026, 1, 1, 0, 0, 1),
        ),
        _msg(
          'tool',
          toolResultsRaw: _toolRaw('list_bots'),
          at: DateTime.utc(2026, 1, 1, 0, 0, 2),
        ),
        _msg(
          'assistant',
          content: 'Tienes 3 bots.',
          at: DateTime.utc(2026, 1, 1, 0, 0, 4),
        ),
      ]);
      expect(turns.length, 1);
      final (turn, trace) = turns.single;
      expect(turn.user?.content, 'Hola');
      expect(turn.responses.map((m) => m.content), <String>['Tienes 3 bots.']);
      expect(trace.nodos.map((n) => n.kind).toList(), <TraceNodeKind>[
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
      ]);
      expect(trace.parcial, isFalse);
      expect(trace.duracion, const Duration(seconds: 4));
    });

    test(
      'los assistant intermedios CON cuerpo son respuestas: ninguna se pierde',
      () {
        // Forma real del wire (conversation_adapter): «déjame ver» + tool_calls
        // en la MISMA fila, y la final. Ambas burbujas deben sobrevivir.
        final turns = traceFromMessages(<PaMessage>[
          _msg('user', content: 'Revisa mis flujos'),
          _msg('assistant', content: 'Déjame revisar…', toolCallsRaw: '[[]]'),
          _msg('tool', toolResultsRaw: _toolRaw('inspect_flow')),
          _msg('assistant', content: 'Listo: hay 3 flujos.'),
        ]);
        final (turn, _) = turns.single;
        expect(turn.responses.map((m) => m.content), <String>[
          'Déjame revisar…',
          'Listo: hay 3 flujos.',
        ]);
      },
    );

    test('un assistant sin su fila user (voz antes de la recarga) se ANEXA — '
        'no pisa la respuesta del turno anterior', () {
      final turns = traceFromMessages(<PaMessage>[
        _msg('user', content: 'hola'),
        _msg('assistant', content: 'resp1'),
        // El cierre del turno de voz anexa el assistant sin fila user.
        _msg('assistant', content: 'respuesta de voz'),
      ]);
      final (turn, _) = turns.single;
      expect(turn.responses.map((m) => m.content), <String>[
        'resp1',
        'respuesta de voz',
      ]);
    });

    test('una fila tool de requires_confirmation va fuera de la traza', () {
      final turns = traceFromMessages(<PaMessage>[
        _msg('user', content: 'Borra el bot'),
        _msg(
          'tool',
          toolResultsRaw: _toolRaw(
            'set_bot_paused',
            errorKind: 'requires_confirmation',
          ),
        ),
      ]);
      final (turn, trace) = turns.single;
      expect(trace.nodos, isEmpty);
      expect(turn.confirmations, hasLength(1));
    });

    test('parte en la frontera user: dos turnos', () {
      final turns = traceFromMessages(<PaMessage>[
        _msg('user', content: 'Uno'),
        _msg('assistant', content: 'Respuesta uno'),
        _msg('user', content: 'Dos'),
        _msg('assistant', content: 'Respuesta dos'),
      ]);
      expect(turns.length, 2);
      expect(turns[0].$1.user?.content, 'Uno');
      expect(turns[1].$1.user?.content, 'Dos');
    });

    test('turno más viejo sin su fila user (paginación) ⇒ parcial', () {
      final turns = traceFromMessages(<PaMessage>[
        _msg('tool', toolResultsRaw: _toolRaw('list_bots')),
        _msg('assistant', content: 'Respuesta truncada'),
        _msg('user', content: 'Turno completo'),
        _msg('assistant', content: 'Su respuesta'),
      ]);
      expect(turns.length, 2);
      expect(turns[0].$1.user, isNull);
      expect(turns[0].$2.parcial, isTrue);
      expect(turns[1].$2.parcial, isFalse);
    });
  });

  group('summarizeTrace', () {
    Trace traceOf(
      List<TraceNodeKind> kinds, {
      bool parcial = false,
      String? fallo,
    }) => Trace(
      nodos: kinds
          .map((k) => TraceNode(kind: k, titulo: 't', icon: Icons.bolt))
          .toList(),
      parcial: parcial,
      fallo: fallo,
    );

    test('con pensamiento: «Pensó · N pasos»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.thinking,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
          ]),
        ),
        'Pensó · 3 pasos',
      );
    });

    test('sin pensamiento: «N pasos»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
            TraceNodeKind.tool,
          ]),
        ),
        '4 pasos',
      );
    });

    test('un solo paso se dice en singular', () {
      expect(summarizeTrace(traceOf([TraceNodeKind.tool])), '1 paso');
    });

    test('solo pensamiento: «Pensó»', () {
      expect(summarizeTrace(traceOf([TraceNodeKind.thinking])), 'Pensó');
    });

    test('parcial: «Usó herramientas», jamás inventa N', () {
      expect(
        summarizeTrace(traceOf([TraceNodeKind.tool], parcial: true)),
        'Usó herramientas',
      );
    });

    test('fallo: «Falló: <causa>»', () {
      expect(
        summarizeTrace(
          traceOf([
            TraceNodeKind.thinking,
          ], fallo: 'La corrida excedió el tiempo límite.'),
        ),
        'Falló: La corrida excedió el tiempo límite.',
      );
    });
  });

  group('capNodes', () {
    TraceNode node(int i) =>
        TraceNode(kind: TraceNodeKind.tool, titulo: 't$i', icon: Icons.bolt);

    test('8 o menos: sin cambios', () {
      final nodes = List.generate(8, node);
      expect(capNodes(nodes), hasLength(8));
      expect(capNodes(nodes).last.kind, TraceNodeKind.tool);
    });

    test('más de 8: 7 + nodo masN «+N pasos más»', () {
      final capped = capNodes(List.generate(10, node));
      expect(capped, hasLength(8));
      expect(capped.last.kind, TraceNodeKind.masN);
      expect(capped.last.titulo, '+3 pasos más');
    });
  });

  group('capNodesLive (el paso actual siempre visible)', () {
    TraceNode node(int i) =>
        TraceNode(kind: TraceNodeKind.tool, titulo: 't$i', icon: Icons.bolt);

    test('8 o menos: sin cambios', () {
      expect(capNodesLive(List.generate(8, node)), hasLength(8));
    });

    test(
      'más de 8: masN al INICIO y los 7 ÚLTIMOS visibles (el actual late)',
      () {
        final capped = capNodesLive(List.generate(12, node));
        expect(capped, hasLength(8));
        expect(capped.first.kind, TraceNodeKind.masN);
        expect(capped.first.titulo, '+5 pasos anteriores');
        expect(capped[1].titulo, 't5');
        expect(capped.last.titulo, 't11');
      },
    );

    test('el mínimo recorte (9 nodos) oculta 2', () {
      expect(
        capNodesLive(List.generate(9, node)).first.titulo,
        '+2 pasos anteriores',
      );
    });
  });

  group('paRunFailureCopy', () {
    test('deadline ⇒ copy es-MX', () {
      expect(
        paRunFailureCopy('context deadline exceeded'),
        'La corrida excedió el tiempo límite.',
      );
    });

    test('desconocido ⇒ genérico es-MX, jamás el crudo del wire', () {
      final copy = paRunFailureCopy('gibberish-token-qqq');
      expect(copy, isNot(contains('qqq')));
      expect(copy, 'La corrida no pudo completarse.');
    });
  });

  test('traceStoppedSummary es el copy honesto de Detener', () {
    expect(traceStoppedSummary, 'Detenido aquí — el servidor pudo continuar');
  });
}
