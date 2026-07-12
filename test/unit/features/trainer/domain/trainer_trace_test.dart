import 'dart:convert';

import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_progress.dart';
import 'package:ataulfo/features/trainer/domain/trainer_trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrainerProgressEvent _ev(
  String kind, {
  String toolName = '',
  bool toolError = false,
  String error = '',
  DateTime? at,
}) => TrainerProgressEvent(
  kind: kind,
  conversationId: 'c1',
  at: at ?? DateTime.utc(2026, 1, 1),
  toolName: toolName,
  toolError: toolError,
  error: error,
);

TrainerMessage _msg(
  String role, {
  String content = '',
  String thinking = '',
  String? toolResultsRaw,
  String? toolCallsRaw,
  DateTime? at,
}) => TrainerMessage(
  id: '${role}_${content.hashCode}_${thinking.hashCode}',
  conversationId: 'c1',
  role: role,
  content: content,
  thinking: thinking,
  toolResultsRaw: toolResultsRaw,
  toolCallsRaw: toolCallsRaw,
  createdAt: at ?? DateTime.utc(2026, 1, 1),
);

/// Envelope del wire del entrenador: camelCase y `content` como STRING JSON
/// doble-codificado (igual que las tarjetas lo parsean).
String _toolRaw(String tool, Map<String, dynamic> content) => jsonEncode(
  <String, dynamic>{'toolName': tool, 'content': jsonEncode(content)},
);

void main() {
  group('nodeFromProgress (gramática viva)', () {
    test('thinking ⇒ nodo etiqueta sin texto', () {
      final n = nodeFromProgress(_ev('thinking'))!;
      expect(n.kind, TraceNodeKind.thinking);
      expect(n.titulo, 'Pensando…');
      expect(n.detalle, isNull);
    });

    test('tool ⇒ nodo con el título humano y el ícono del tool', () {
      final n = nodeFromProgress(_ev('tool', toolName: 'inspect_flow'))!;
      expect(n.kind, TraceNodeKind.tool);
      expect(n.titulo, 'Inspeccionó un flujo');
      expect(n.icon, Icons.account_tree_outlined);
      expect(n.isError, isFalse);
    });

    test('tool sin nombre ⇒ «Trabajando…»', () {
      expect(nodeFromProgress(_ev('tool'))!.titulo, 'Trabajando…');
    });

    test('toolError marca el nodo como error', () {
      expect(
        nodeFromProgress(
          _ev('tool', toolName: 'edit_doc', toolError: true),
        )!.isError,
        isTrue,
      );
    });

    test('tool en error NO reclama éxito: titula el fallo honesto', () {
      final n = nodeFromProgress(
        _ev('tool', toolName: 'edit_doc', toolError: true),
      )!;
      // El título de éxito «Documento actualizado» sería mentira: el tool falló.
      expect(n.titulo, isNot('Documento actualizado'));
      expect(n.titulo, trainerToolErrorCopy(''));
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
      final t = liveTrace(<TrainerProgressEvent>[
        _ev('thinking'),
        _ev('thinking'),
        _ev('tool', toolName: 'read_prompt'),
        _ev('thinking'),
        _ev('tool', toolName: 'edit_prompt'),
      ]);
      expect(t.nodos.map((n) => n.kind).toList(), <TraceNodeKind>[
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
      ]);
      expect(t.parcial, isFalse);
    });

    test('un failed antes del cierre aporta la causa es-MX al resumen '
        '(copy del núcleo, sin resúmenes propios)', () {
      final t = liveTrace(<TrainerProgressEvent>[
        _ev('thinking'),
        _ev('failed', error: 'context deadline exceeded'),
      ]);
      expect(t.fallo, 'La corrida excedió el tiempo límite.');
      expect(summarizeTrace(t), 'Falló: La corrida excedió el tiempo límite.');
    });

    test('duración = del primer evento al cierre', () {
      final t = liveTrace(<TrainerProgressEvent>[
        _ev('thinking', at: DateTime.utc(2026, 1, 1, 0, 0, 0)),
      ], closedAt: DateTime.utc(2026, 1, 1, 0, 0, 5));
      expect(t.duracion, const Duration(seconds: 5));
    });
  });

  group('traceFromMessages (gramática persistida)', () {
    test('agrupa un turno completo: user, proceso y respuesta final', () {
      final turns = traceFromMessages(<TrainerMessage>[
        _msg(
          'user',
          content: 'mejora el tono',
          at: DateTime.utc(2026, 1, 1, 0, 0, 0),
        ),
        _msg(
          'assistant',
          thinking: 'Debo leer el prompt',
          toolCallsRaw: '[]',
          at: DateTime.utc(2026, 1, 1, 0, 0, 1),
        ),
        _msg(
          'tool',
          toolResultsRaw: _toolRaw('edit_prompt', <String, dynamic>{
            'status': 'updated',
          }),
          at: DateTime.utc(2026, 1, 1, 0, 0, 2),
        ),
        _msg(
          'assistant',
          content: 'Listo, tono cálido.',
          at: DateTime.utc(2026, 1, 1, 0, 0, 4),
        ),
      ]);
      expect(turns.length, 1);
      final (turn, trace) = turns.single;
      expect(turn.user?.content, 'mejora el tono');
      expect(turn.responses.map((m) => m.content), <String>[
        'Listo, tono cálido.',
      ]);
      expect(trace.nodos.map((n) => n.kind).toList(), <TraceNodeKind>[
        TraceNodeKind.thinking,
        TraceNodeKind.tool,
      ]);
      // El nodo tool lee IGUAL que su tarjeta (mapa central).
      expect(trace.nodos.last.titulo, 'Prompt actualizado');
      expect(turn.toolMessages, hasLength(1));
      expect(trace.parcial, isFalse);
      expect(trace.duracion, const Duration(seconds: 4));
    });

    test('el thinking persistido viaja CON texto como detalle del nodo '
        '(filas viejas sin texto no rinden nodo)', () {
      final turns = traceFromMessages(<TrainerMessage>[
        _msg('user', content: 'hola'),
        _msg('assistant', thinking: 'razono esto', toolCallsRaw: '[]'),
        _msg('assistant', thinking: '', toolCallsRaw: '[]'),
        _msg('assistant', content: 'respuesta'),
      ]);
      final (_, trace) = turns.single;
      final thinkingNodes = trace.nodos
          .where((n) => n.kind == TraceNodeKind.thinking)
          .toList();
      expect(thinkingNodes, hasLength(1));
      expect(thinkingNodes.single.detalle, 'razono esto');
    });

    test('una tool con error_kind rinde nodo en error y sigue alineable', () {
      final turns = traceFromMessages(<TrainerMessage>[
        _msg('user', content: 'edita el doc'),
        _msg(
          'tool',
          toolResultsRaw: _toolRaw('edit_doc', <String, dynamic>{
            'error_kind': 'not_found',
          }),
        ),
      ]);
      final (turn, trace) = turns.single;
      expect(trace.nodos.single.kind, TraceNodeKind.tool);
      expect(trace.nodos.single.isError, isTrue);
      expect(turn.toolMessages, hasLength(1));
    });

    test('una tool FALLIDA titula el fallo honesto — jamás reclama éxito '
        '(alinea con la TrainerToolErrorCard)', () {
      final turns = traceFromMessages(<TrainerMessage>[
        _msg('user', content: 'edita el doc'),
        _msg(
          'tool',
          toolResultsRaw: _toolRaw('edit_doc', <String, dynamic>{
            'error_kind': 'not_found',
          }),
        ),
      ]);
      final (_, trace) = turns.single;
      final node = trace.nodos.single;
      expect(node.isError, isTrue);
      // El título de éxito «Documento actualizado» sería mentira: el edit falló.
      expect(node.titulo, isNot('Documento actualizado'));
      // Registro honesto y genérico; el motivo específico vive en la tarjeta.
      expect(node.titulo, trainerToolErrorCopy(''));
    });

    test(
      'los assistant intermedios CON cuerpo son respuestas: ninguna se pierde',
      () {
        final turns = traceFromMessages(<TrainerMessage>[
          _msg('user', content: 'revisa mis flujos'),
          _msg('assistant', content: 'Déjame revisar…', toolCallsRaw: '[[]]'),
          _msg(
            'tool',
            toolResultsRaw: _toolRaw('inspect_flow', <String, dynamic>{
              'name': 'Bienvenida',
            }),
          ),
          _msg('assistant', content: 'Listo: hay 3 flujos.'),
        ]);
        final (turn, _) = turns.single;
        expect(turn.responses.map((m) => m.content), <String>[
          'Déjame revisar…',
          'Listo: hay 3 flujos.',
        ]);
      },
    );

    test('parte en la frontera user: dos turnos', () {
      final turns = traceFromMessages(<TrainerMessage>[
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
      final turns = traceFromMessages(<TrainerMessage>[
        _msg(
          'tool',
          toolResultsRaw: _toolRaw('read_doc', <String, dynamic>{
            'name': 'menu',
          }),
        ),
        _msg('assistant', content: 'Respuesta truncada'),
        _msg('user', content: 'Turno completo'),
        _msg('assistant', content: 'Su respuesta'),
      ]);
      expect(turns.length, 2);
      expect(turns[0].$1.user, isNull);
      expect(turns[0].$2.parcial, isTrue);
      expect(turns[1].$2.parcial, isFalse);
      expect(summarizeTrace(turns[0].$2), 'Usó herramientas');
    });

    test('una tool con envelope ilegible degrada a nodo genérico', () {
      final turns = traceFromMessages(<TrainerMessage>[
        _msg('user', content: 'x'),
        _msg('tool', toolResultsRaw: 'no-es-json'),
      ]);
      final (turn, trace) = turns.single;
      expect(trace.nodos.single.titulo, 'Usó una herramienta');
      expect(turn.toolMessages, hasLength(1));
    });
  });
}
