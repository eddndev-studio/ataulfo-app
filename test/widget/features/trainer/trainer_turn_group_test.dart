import 'dart:convert';

import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/core/widgets/trace_timeline.dart';
import 'package:ataulfo/features/trainer/domain/entities/trainer_message.dart';
import 'package:ataulfo/features/trainer/domain/trainer_trace.dart';
import 'package:ataulfo/features/trainer/presentation/widgets/trainer_turn_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/chat_media_providers.dart';

String _toolRaw(String toolName, Map<String, dynamic> content) => jsonEncode(
  <String, dynamic>{'toolName': toolName, 'content': jsonEncode(content)},
);

TrainerMessage _m(
  String id,
  String role, {
  String content = '',
  String thinking = '',
  String? toolResultsRaw,
  int sec = 0,
}) => TrainerMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  content: content,
  thinking: thinking,
  toolResultsRaw: toolResultsRaw,
  createdAt: DateTime.utc(2026, 6, 10, 10, 0, sec),
);

Widget _host((TrainerTurn, Trace) turn) => MaterialApp(
  home: Scaffold(
    body: wrapWithChatMedia(
      SingleChildScrollView(
        child: TrainerTurnGroup(turn: turn.$1, trace: turn.$2),
      ),
    ),
  ),
);

void main() {
  testWidgets('turno completo: user + traza colapsada + respuesta fuera; la '
      'tarjeta de diff vive como cuerpo del nodo', (tester) async {
    final turns = traceFromMessages(<TrainerMessage>[
      _m('u', 'user', content: 'mejora el tono', sec: 0),
      _m('a1', 'assistant', thinking: 'razono esto', sec: 1),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('edit_prompt', <String, dynamic>{
          'name': 'prompt',
          'diff': <String, dynamic>{'old': 'seco', 'new': 'cálido'},
        }),
        sec: 2,
      ),
      _m('a2', 'assistant', content: 'Listo, tono cálido.', sec: 4),
    ]);
    await tester.pumpWidget(_host(turns.single));

    // La burbuja del operador y la respuesta (markdown) están siempre visibles.
    expect(find.text('mejora el tono'), findsOneWidget);
    expect(find.byType(AssistantMarkdown), findsOneWidget);

    // Colapsada: el resumen (con duración aproximada) se ve; ni el
    // razonamiento ni la tarjeta de cambio (están dentro del colapso).
    expect(find.textContaining('Pensó · 1 paso · ~4s'), findsOneWidget);
    expect(find.text('Razonamiento'), findsNothing);
    expect(find.byKey(const Key('trainer.change_card.t1')), findsNothing);

    // Al expandir aparecen los nodos: razonamiento (texto inline) y el paso
    // tool con la tarjeta de cambio como cuerpo — que conserva su expandir.
    await tester.tap(find.textContaining('Pensó · 1 paso'));
    await tester.pump();
    expect(find.text('Razonamiento'), findsOneWidget);
    expect(find.text('razono esto'), findsOneWidget);
    expect(find.byKey(const Key('trainer.change_card.t1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('trainer.change_card.t1')));
    await tester.pump();
    expect(find.text('seco'), findsOneWidget);
    expect(find.text('cálido'), findsOneWidget);
  });

  testWidgets('una tool fallida: nodo en error con la tarjeta de error como '
      'cuerpo', (tester) async {
    final turns = traceFromMessages(<TrainerMessage>[
      _m('u', 'user', content: 'edita el doc', sec: 0),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('edit_doc', <String, dynamic>{
          'error_kind': 'not_found',
        }),
        sec: 1,
      ),
    ]);
    await tester.pumpWidget(_host(turns.single));

    // Colapsada, el resumen delata el paso; la tarjeta está dentro.
    expect(find.byKey(const Key('trainer.error_card.t1')), findsNothing);
    await tester.tap(find.textContaining('1 paso'));
    await tester.pump();
    expect(find.byKey(const Key('trainer.error_card.t1')), findsOneWidget);
    expect(find.text('Documento actualizado'), findsOneWidget);
  });

  testWidgets('TODAS las respuestas con cuerpo se pintan (el preámbulo del '
      'intermedio no se pierde)', (tester) async {
    final turns = traceFromMessages(<TrainerMessage>[
      _m('u', 'user', content: 'revisa mis flujos', sec: 0),
      _m('a1', 'assistant', content: 'Déjame revisar…', sec: 1),
      _m(
        't1',
        'tool',
        toolResultsRaw: _toolRaw('inspect_flow', <String, dynamic>{
          'name': 'Bienvenida',
          'is_active': true,
          'steps': <dynamic>[],
          'triggers': <dynamic>[],
        }),
        sec: 2,
      ),
      _m('a2', 'assistant', content: 'Listo: hay 3 flujos.', sec: 3),
    ]);
    await tester.pumpWidget(_host(turns.single));
    expect(find.byType(AssistantMarkdown), findsNWidgets(2));

    // La tarjeta de inspección vive como cuerpo del nodo al expandir.
    await tester.tap(find.textContaining('1 paso'));
    await tester.pump();
    expect(find.byKey(const Key('trainer.inspect_card.t1')), findsOneWidget);
  });

  testWidgets('turno parcial SIN nodos: no hay timeline que expandir a vacío', (
    tester,
  ) async {
    // Página cortada por la paginación: solo llegó la respuesta final.
    final turns = traceFromMessages(<TrainerMessage>[
      _m('a9', 'assistant', content: 'Listo.'),
    ]);
    final (_, trace) = turns.single;
    expect(trace.parcial, isTrue);
    await tester.pumpWidget(_host(turns.single));
    expect(find.byType(TraceTimeline), findsNothing);
    expect(find.byType(AssistantMarkdown), findsOneWidget);
  });
}
