import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/core/design/widgets/chat_bubble.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:ataulfo/features/ai_log/presentation/bloc/ai_log_bloc.dart';
import 'package:ataulfo/features/ai_log/presentation/pages/ai_log_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<AiLogEvent, AiLogState> implements AiLogBloc {}

AiLogEntry e(
  int id, {
  String runId = 'r1',
  AiLogRole role = AiLogRole.assistant,
  String content = '',
  String reasoning = '',
  List<AiToolCall> toolCalls = const <AiToolCall>[],
  String toolName = '',
  String model = '',
  int promptTokens = 0,
  int completionTokens = 0,
  int totalTokens = 0,
  int cachedTokens = 0,
  int costMicroUsd = 0,
}) => AiLogEntry(
  id: id,
  runId: runId,
  role: role,
  content: content,
  reasoning: reasoning,
  toolCalls: toolCalls,
  toolCallId: '',
  toolName: toolName,
  model: model,
  promptTokens: promptTokens,
  completionTokens: completionTokens,
  totalTokens: totalTokens,
  cachedTokens: cachedTokens,
  costMicroUsd: costMicroUsd,
  createdAt: DateTime.utc(2026, 6, 12, 12),
);

void main() {
  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<AiLogBloc>.value(
          value: bloc,
          child: const Scaffold(body: AiLogPage()),
        ),
      ),
    );
  }

  testWidgets('pinta la corrida: cliente, razonamiento colapsable, llamada a '
      'tool expandible, resultado y tokens', (tester) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(4, content: 'Abrimos 9-18.', model: 'm1', totalTokens: 15),
          e(3, role: AiLogRole.tool, toolName: 'read_doc', content: 'L-V 9-18'),
          e(
            2,
            reasoning: 'consulto el doc de horarios',
            toolCalls: const <AiToolCall>[
              AiToolCall(
                id: 'c0',
                name: 'read_doc',
                argumentsJson: '{"doc":"horarios"}',
              ),
            ],
          ),
          e(1, role: AiLogRole.user, content: '¿horario?'),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    expect(find.text('¿horario?'), findsOneWidget);
    expect(find.text('Abrimos 9-18.'), findsOneWidget);
    expect(find.byKey(const Key('reasoning.disclosure.2')), findsOneWidget);
    expect(find.byKey(const Key('ai_log.tool_result.3')), findsOneWidget);
    expect(find.text('15 tokens'), findsOneWidget);
    // El razonamiento arranca colapsado; al expandir aparece el texto.
    expect(find.text('consulto el doc de horarios'), findsNothing);
    await tester.tap(find.byKey(const Key('reasoning.disclosure.2')));
    await tester.pumpAndSettle();
    expect(find.text('consulto el doc de horarios'), findsOneWidget);
    // La llamada a tool: nombre visible con glifo (no un emoji en el label) y
    // los argumentos expandibles al TOCAR — un tooltip de hover no sirve en
    // táctil.
    expect(find.text('read_doc'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    expect(find.text('{"doc":"horarios"}'), findsNothing);
    await tester.tap(find.byKey(const Key('ai_log.tool_call.c0')));
    await tester.pumpAndSettle();
    expect(find.text('{"doc":"horarios"}'), findsOneWidget);
  });

  testWidgets('tool-call sin argumentos muestra "(sin argumentos)" al '
      'expandir', (tester) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(
            1,
            toolCalls: const <AiToolCall>[
              AiToolCall(id: 'c1', name: 'done', argumentsJson: ''),
            ],
          ),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    expect(find.text('(sin argumentos)'), findsNothing);
    await tester.tap(find.byKey(const Key('ai_log.tool_call.c1')));
    await tester.pumpAndSettle();
    expect(find.text('(sin argumentos)'), findsOneWidget);
  });

  testWidgets('user y assistant van en ChatBubble del kit; solo el cliente '
      'a la derecha, con su caption de rol', (tester) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(2, content: 'buenas'),
          e(1, role: AiLogRole.user, content: 'hola'),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    final bubbles = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .toList();
    expect(bubbles.length, 2);
    expect(bubbles.where((b) => b.mine).length, 1);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Bot'), findsOneWidget);
  });

  testWidgets('el contenido del bot renderiza Markdown; el del cliente va '
      'verbatim', (tester) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(2, content: 'Claro, con **gusto**.'),
          e(1, role: AiLogRole.user, content: 'pásame el *menú*'),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    // El operador ve la negrita renderizada, no los asteriscos crudos.
    expect(find.byType(AssistantMarkdown), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    // El turno del cliente es transcripción verbatim de WhatsApp: los
    // asteriscos se muestran tal cual llegaron.
    expect(find.text('pásame el *menú*'), findsOneWidget);
  });

  testWidgets('el aviso del motor (rol system) se rotula Sistema, no Cliente', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(
            2,
            role: AiLogRole.system,
            content:
                '[AVISO DEL SISTEMA — esto NO es un mensaje de la persona]',
          ),
          e(1, role: AiLogRole.user, content: 'hola'),
        ],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.textContaining('AVISO DEL SISTEMA'), findsOneWidget);
    // El único "Cliente" es el turno user real — el aviso ya no usurpa su voz.
    expect(find.text('Cliente'), findsOneWidget);
    // Y no cae al fallback de turno no soportado.
    expect(find.textContaining('Turno no soportado'), findsNothing);
  });

  testWidgets('cursor presente → botón "Cargar anteriores" dispara more', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[e(1, role: AiLogRole.user, content: 'hola')],
        nextBefore: 1,
        isLoadingMore: false,
      ),
    );
    await pump(tester);

    await tester.tap(find.byKey(const Key('ai_log.load_more')));
    verify(() => bloc.add(const AiLogMoreRequested())).called(1);
  });

  testWidgets('vacío → copy honesto', (tester) async {
    when(() => bloc.state).thenReturn(
      const AiLogLoaded(
        entries: <AiLogEntry>[],
        nextBefore: null,
        isLoadingMore: false,
      ),
    );
    await pump(tester);
    expect(find.byKey(const Key('ai_log.empty')), findsOneWidget);
  });

  // ── header de tokens/costo de la corrida ─────────────────────────────
  group('header de tokens de la corrida', () {
    void load(List<AiLogEntry> entries) {
      when(() => bloc.state).thenReturn(
        AiLogLoaded(entries: entries, nextBefore: null, isLoadingMore: false),
      );
    }

    testWidgets(
      'pills de entrada/salida, caché y costo con el split del wire',
      (tester) async {
        load(<AiLogEntry>[
          e(
            1,
            content: 'ok',
            promptTokens: 730,
            completionTokens: 120,
            totalTokens: 850,
            cachedTokens: 100,
            costMicroUsd: 1250000,
          ),
        ]);
        await pump(tester);

        // Entrada/salida como pills con glifo de flecha del kit, no un
        // carácter Unicode incrustado en el label.
        expect(find.text('730'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
        // 100/730 = 13.69…% ⇒ el redondeo debe subir a 14.
        expect(find.text('caché 14%'), findsOneWidget);
        expect(find.text(r'$1.25'), findsOneWidget);
        // Con split presente NO aparece el pill legado de total, aunque el
        // total venga poblado (la condición del fallback es el split ausente).
        expect(find.text('850 tokens'), findsNothing);
        expect(find.textContaining('tokens'), findsNothing);
      },
    );

    testWidgets('caché que redondea a 0% no pinta el pill', (tester) async {
      load(<AiLogEntry>[
        e(1, promptTokens: 35000, completionTokens: 10, cachedTokens: 30),
      ]);
      await pump(tester);

      expect(find.text('35k'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.textContaining('caché'), findsNothing);
    });

    testWidgets('sin caché ni costo: solo los pills de entrada/salida', (
      tester,
    ) async {
      load(<AiLogEntry>[e(1, promptTokens: 1200, completionTokens: 35000)]);
      await pump(tester);

      expect(find.text('1.2k'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('35k'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.textContaining('caché'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('fallback legado: sin split pero con total ⇒ "N tokens"', (
      tester,
    ) async {
      load(<AiLogEntry>[e(1, totalTokens: 15)]);
      await pump(tester);

      expect(find.text('15 tokens'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });
  });

  // ── dispatch del turno role=tool por toolName ────────────────────────
  group('render de turnos tool por toolName', () {
    const analysisWire =
        '{"kind":"chat_analysis","summary":"resumen X","facts":[],'
        '"sentiment":"","timeline":[],"truncated":false}';
    const subagentWire =
        '{"status":"completed","summary":"hice la tarea","result":"r"}';

    void load(AiLogEntry entry) {
      when(() => bloc.state).thenReturn(
        AiLogLoaded(
          entries: <AiLogEntry>[entry],
          nextBefore: null,
          isLoadingMore: false,
        ),
      );
    }

    testWidgets('analyze_chat con envelope válido → AnalysisCard, no el blob', (
      tester,
    ) async {
      load(
        e(
          5,
          role: AiLogRole.tool,
          toolName: 'analyze_chat',
          content: analysisWire,
        ),
      );
      await pump(tester);
      expect(find.text('resumen X'), findsOneWidget);
      expect(find.byKey(const Key('ai_log.tool_result.5')), findsNothing);
    });

    testWidgets('spawn_agent con outcome válido → SubagentOutcomeCard', (
      tester,
    ) async {
      load(
        e(
          6,
          role: AiLogRole.tool,
          toolName: 'spawn_agent',
          content: subagentWire,
        ),
      );
      await pump(tester);
      expect(find.text('hice la tarea'), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
      expect(find.byKey(const Key('ai_log.tool_result.6')), findsNothing);
    });

    testWidgets('GATE: analyze_chat con content malformado → cae al blob', (
      tester,
    ) async {
      load(
        e(
          7,
          role: AiLogRole.tool,
          toolName: 'analyze_chat',
          content: 'no soy json',
        ),
      );
      await pump(tester);
      expect(find.byKey(const Key('ai_log.tool_result.7')), findsOneWidget);
      // El blob del fallback conserva el icono de la tool (no el default).
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
      // Y vive en un AppCard.outline del kit: sus ancestros AppCard son la
      // tarjeta de la corrida MÁS la del blob (2), no solo la corrida.
      expect(
        find.ancestor(
          of: find.byKey(const Key('ai_log.tool_result.7')),
          matching: find.byType(AppCard),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('toolName desconocido (read_messages) → blob con su icono', (
      tester,
    ) async {
      load(
        e(
          8,
          role: AiLogRole.tool,
          toolName: 'read_messages',
          content: '[{"x":1}]',
        ),
      );
      await pump(tester);
      expect(find.byKey(const Key('ai_log.tool_result.8')), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    });

    testWidgets('search_messages → blob con icono de búsqueda', (tester) async {
      load(
        e(9, role: AiLogRole.tool, toolName: 'search_messages', content: '[]'),
      );
      await pump(tester);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tool sin icono propio → icono por defecto', (tester) async {
      load(e(10, role: AiLogRole.tool, toolName: 'apply_label', content: 'ok'));
      await pump(tester);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });
  });
}
