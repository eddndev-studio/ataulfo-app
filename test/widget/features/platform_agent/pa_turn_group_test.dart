import 'dart:convert';

import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/core/widgets/trace_timeline.dart';
import 'package:ataulfo/features/platform_agent/domain/entities/pa_message.dart';
import 'package:ataulfo/features/platform_agent/domain/pa_trace.dart';
import 'package:ataulfo/features/platform_agent/presentation/widgets/pa_turn_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/chat_media_providers.dart';

String _toolRaw(String toolName, Map<String, dynamic> content) => jsonEncode(
  <String, dynamic>{'tool_name': toolName, 'content': jsonEncode(content)},
);

PaMessage _m(
  String id,
  String role, {
  String content = '',
  String thinking = '',
  String? toolResultsRaw,
  int sec = 0,
}) => PaMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  thinking: thinking,
  toolResultsRaw: toolResultsRaw,
  createdAt: DateTime.utc(2026, 6, 10, 10, 0, sec),
);

Widget _host((PaTurn, Trace) turn) => MaterialApp(
  home: Scaffold(
    body: wrapWithChatMedia(
      SingleChildScrollView(
        child: PaTurnGroup(turn: turn.$1, trace: turn.$2, onConfirm: () {}),
      ),
    ),
  ),
);

void main() {
  testWidgets('turno completo: user + traza colapsada + respuesta fuera', (
    tester,
  ) async {
    final turns = traceFromMessages(<PaMessage>[
      _m('u', 'user', content: 'mi pregunta', sec: 0),
      _m('a1', 'assistant', thinking: 'razono esto', sec: 1),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('list_bots', <String, dynamic>{
          'bots': <dynamic>[],
        }),
        sec: 2,
      ),
      _m('a2', 'assistant', content: 'La respuesta final', sec: 4),
    ]);
    await tester.pumpWidget(_host(turns.single));

    // La burbuja del operador y la respuesta (markdown) están siempre visibles.
    expect(find.text('mi pregunta'), findsOneWidget);
    expect(find.byType(AssistantMarkdown), findsOneWidget);

    // Colapsada: el resumen (con duración aproximada) se ve; el razonamiento
    // NO (está dentro del colapso).
    expect(find.textContaining('Pensó · 1 paso · ~4s'), findsOneWidget);
    expect(find.text('Razonamiento'), findsNothing);

    // Al expandir aparecen los nodos: el razonamiento (título + texto inline,
    // sin un segundo plegado) y el paso tool.
    await tester.tap(find.textContaining('Pensó · 1 paso'));
    await tester.pump();
    expect(find.text('Razonamiento'), findsOneWidget);
    expect(find.text('razono esto'), findsOneWidget);
    expect(find.text('Consultó los bots'), findsOneWidget);
  });

  testWidgets('la confirmación queda SIEMPRE fuera de la traza', (
    tester,
  ) async {
    final turns = traceFromMessages(<PaMessage>[
      _m('u', 'user', content: 'borra un bot', sec: 0),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('set_bot_paused', <String, dynamic>{
          'error_kind': 'requires_confirmation',
          'bots': <dynamic>[
            <String, dynamic>{'name': 'Ventas'},
          ],
        }),
        sec: 1,
      ),
    ]);
    await tester.pumpWidget(_host(turns.single));
    // Sin nodos en la traza (la única tool es confirmación): la tarjeta de
    // confirmación se ve sin necesidad de expandir nada.
    expect(find.byKey(const Key('pa.confirm.accept')), findsOneWidget);
  });

  testWidgets('TODAS las respuestas con cuerpo se pintan (el preámbulo del '
      'intermedio no se pierde)', (tester) async {
    final turns = traceFromMessages(<PaMessage>[
      _m('u', 'user', content: 'revisa mis flujos', sec: 0),
      _m('a1', 'assistant', content: 'Déjame revisar…', sec: 1),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('inspect_flow', <String, dynamic>{}),
        sec: 2,
      ),
      _m('a2', 'assistant', content: 'Listo: hay 3 flujos.', sec: 3),
    ]);
    await tester.pumpWidget(_host(turns.single));
    expect(find.byType(AssistantMarkdown), findsNWidgets(2));
  });

  testWidgets('turno parcial SIN nodos: no hay timeline que expandir a vacío', (
    tester,
  ) async {
    // Página cortada por la paginación: solo llegó la respuesta final.
    final turns = traceFromMessages(<PaMessage>[
      _m('a9', 'assistant', content: 'Tienes 3 bots.'),
    ]);
    final (_, trace) = turns.single;
    expect(trace.parcial, isTrue);
    await tester.pumpWidget(_host(turns.single));
    expect(find.byType(TraceTimeline), findsNothing);
    expect(find.byType(AssistantMarkdown), findsOneWidget);
  });
}
