import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/assistant_markdown.dart';
import 'package:ataulfo/core/design/widgets/chat_bubble.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_log_entry.dart';
import 'package:ataulfo/features/ai_log/domain/entities/ai_run_outcome.dart';
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
  String toolCallId = '',
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
  toolCallId: toolCallId,
  toolName: toolName,
  model: model,
  promptTokens: promptTokens,
  completionTokens: completionTokens,
  totalTokens: totalTokens,
  cachedTokens: cachedTokens,
  costMicroUsd: costMicroUsd,
  createdAt: DateTime.utc(2026, 6, 12, 12, 0, id),
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

  void load(
    List<AiLogEntry> entries, {
    int? nextBefore,
    bool drill = false,
    AiRunOutcome? run,
  }) {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: entries,
        nextBefore: nextBefore,
        isLoadingMore: false,
        drill: drill,
        run: run,
      ),
    );
  }

  group('la corrida como turno estilo Claude (La Traza F5)', () {
    testWidgets('burbujas fuera del colapso; el proceso colapsado a su '
        'resumen y expandible a traza con títulos humanos', (tester) async {
      load(<AiLogEntry>[
        e(4, content: 'Abrimos 9-18.', model: 'm1', totalTokens: 15),
        e(
          3,
          role: AiLogRole.tool,
          toolName: 'read_doc',
          toolCallId: 'c0',
          content: 'L-V 9-18',
        ),
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
      ]);
      await pump(tester);

      // Cliente y respuesta SIEMPRE a la vista; el header con el total legado.
      expect(find.text('¿horario?'), findsOneWidget);
      expect(find.text('Abrimos 9-18.'), findsOneWidget);
      expect(find.text('15 tokens'), findsOneWidget);
      // El proceso, colapsado al resumen del core (pensó + 1 tool).
      expect(find.textContaining('Pensó · 1 paso'), findsOneWidget);
      expect(find.text('Leyó un documento'), findsNothing);
      expect(find.text('consulto el doc de horarios'), findsNothing);

      await tester.tap(find.byKey(const Key('ai_log.run_trace.r1')));
      // El carril abre animado (AnimatedSize): asentar antes de tocar un cuerpo
      // interno, que hasta que el reveal termina queda recortado.
      await tester.pumpAndSettle();

      // Nodos con título humano (jamás el crudo) y el razonamiento como
      // cuerpo del nodo thinking — sin un segundo plegado propio.
      expect(find.text('Razonamiento'), findsOneWidget);
      expect(find.text('consulto el doc de horarios'), findsOneWidget);
      expect(find.text('Leyó un documento'), findsOneWidget);
      // El resultado del tool cuelga del nodo; los argumentos, plegados.
      expect(find.byKey(const Key('ai_log.tool_result.3')), findsOneWidget);
      expect(find.text('{"doc":"horarios"}'), findsNothing);
      await tester.tap(find.byKey(const Key('ai_log.tool_call.c0')));
      await tester.pumpAndSettle();
      expect(find.text('{"doc":"horarios"}'), findsOneWidget);
    });

    testWidgets('user y assistant van en ChatBubble del kit; solo el cliente '
        'a la derecha, con su caption de rol', (tester) async {
      load(<AiLogEntry>[
        e(2, content: 'buenas'),
        e(1, role: AiLogRole.user, content: 'hola'),
      ]);
      await pump(tester);

      final bubbles = tester
          .widgetList<ChatBubble>(find.byType(ChatBubble))
          .toList();
      expect(bubbles.length, 2);
      expect(bubbles.where((b) => b.mine).length, 1);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Asistente'), findsOneWidget);
    });

    testWidgets('el contenido del bot renderiza Markdown; el del cliente va '
        'verbatim', (tester) async {
      load(<AiLogEntry>[
        e(2, content: 'Claro, con **gusto**.'),
        e(1, role: AiLogRole.user, content: 'pásame el *menú*'),
      ]);
      await pump(tester);

      // El operador ve la negrita renderizada, no los asteriscos crudos.
      expect(find.byType(AssistantMarkdown), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
      // El turno del cliente es transcripción verbatim de WhatsApp: los
      // asteriscos se muestran tal cual llegaron.
      expect(find.text('pásame el *menú*'), findsOneWidget);
    });

    testWidgets('el aviso del motor (rol system) es un nodo de la traza, '
        'no una burbuja que usurpe la voz del cliente', (tester) async {
      load(<AiLogEntry>[
        e(
          2,
          role: AiLogRole.system,
          content: '[AVISO DEL SISTEMA — esto NO es un mensaje de la persona]',
        ),
        e(1, role: AiLogRole.user, content: 'hola'),
      ]);
      await pump(tester);

      await tester.tap(find.byKey(const Key('ai_log.run_trace.r1')));
      // El carril abre animado (AnimatedSize): asentar antes de tocar un cuerpo
      // interno, que hasta que el reveal termina queda recortado.
      await tester.pumpAndSettle();
      expect(find.text('Aviso del sistema'), findsOneWidget);
      expect(find.textContaining('AVISO DEL SISTEMA'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.textContaining('Turno no soportado'), findsNothing);
    });

    testWidgets(
      'la corrida partida por la frontera de paginación no inventa N',
      (tester) async {
        // Solo el tramo final de la corrida quedó en la ventana (hay página
        // anterior): el resumen degrada a «Usó herramientas».
        load(<AiLogEntry>[
          e(12, runId: 'r9', content: 'listo'),
          e(11, runId: 'r9', role: AiLogRole.tool, toolName: 'read_doc'),
        ], nextBefore: 10);
        await pump(tester);
        expect(find.textContaining('Usó herramientas'), findsOneWidget);
        expect(find.textContaining('paso'), findsNothing);
      },
    );
  });

  group('historia legacy («Actividad previa»)', () {
    testWidgets('las filas sin run_id caen planas, sin agrupación inventada', (
      tester,
    ) async {
      load(<AiLogEntry>[
        e(4, content: 'Abrimos 9-18.'),
        e(3, role: AiLogRole.user, content: '¿horario?'),
        e(2, runId: '', content: 'respuesta vieja'),
        e(1, runId: '', role: AiLogRole.user, content: 'hola de antes'),
      ]);
      await pump(tester);

      expect(find.byKey(const Key('ai_log.legacy')), findsOneWidget);
      expect(find.text('Actividad previa'), findsOneWidget);
      // Render plano original: el contenido legacy visible sin expandir nada.
      expect(find.text('hola de antes'), findsOneWidget);
      expect(find.text('respuesta vieja'), findsOneWidget);
    });

    testWidgets('tool-call sin argumentos muestra "(sin argumentos)" al '
        'expandir (render plano)', (tester) async {
      load(<AiLogEntry>[
        e(
          1,
          runId: '',
          toolCalls: const <AiToolCall>[
            AiToolCall(id: 'c1', name: 'done', argumentsJson: ''),
          ],
        ),
      ]);
      await pump(tester);

      expect(find.text('(sin argumentos)'), findsNothing);
      await tester.tap(find.byKey(const Key('ai_log.tool_call.c1')));
      await tester.pumpAndSettle();
      expect(find.text('(sin argumentos)'), findsOneWidget);
    });

    testWidgets('el aviso del motor legacy se rotula Sistema, no Cliente', (
      tester,
    ) async {
      load(<AiLogEntry>[
        e(2, runId: '', role: AiLogRole.system, content: '[AVISO DEL SISTEMA]'),
        e(1, runId: '', role: AiLogRole.user, content: 'hola'),
      ]);
      await pump(tester);

      expect(find.text('Sistema'), findsOneWidget);
      expect(find.textContaining('AVISO DEL SISTEMA'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.textContaining('Turno no soportado'), findsNothing);
    });
  });

  group('drill de una corrida (?run= / ?msg=)', () {
    AiRunOutcome outcome({String status = 'COMPLETED', String error = ''}) =>
        AiRunOutcome(
          status: status,
          error: error,
          iterations: 3,
          tokensIn: 100,
          tokensOut: 40,
          startedAt: DateTime.utc(2026, 7, 1, 10),
          endedAt: DateTime.utc(2026, 7, 1, 10, 0, 42),
        );

    List<AiLogEntry> runDesc() => <AiLogEntry>[
      e(3, content: 'Abrimos 9-18.'),
      e(2, role: AiLogRole.tool, toolName: 'read_doc'),
      e(1, role: AiLogRole.user, content: '¿horario?'),
    ];

    testWidgets('la corrida nace expandida y cierra con el desenlace ✓ y '
        'duración SIEMPRE aproximada («~»)', (tester) async {
      load(runDesc(), drill: true, run: outcome());
      await pump(tester);

      // Expandida sin tocar nada: los nodos y el desenlace a la vista.
      expect(find.text('Leyó un documento'), findsOneWidget);
      expect(find.text('Corrida completada · ~42s'), findsOneWidget);
    });

    testWidgets('el fallo del desenlace SIEMPRE es-MX; el crudo queda '
        'plegado como detalle técnico', (tester) async {
      load(
        runDesc(),
        drill: true,
        run: outcome(status: 'FAILED', error: 'context deadline exceeded'),
      );
      await pump(tester);

      expect(
        find.text('La corrida excedió el tiempo límite · ~42s'),
        findsOneWidget,
      );
      // El crudo NO está a la vista; vive dentro del pliegue técnico.
      expect(find.text('context deadline exceeded'), findsNothing);
      // El pliegue anuncia su naturaleza con el literal fijado.
      expect(find.text('Detalle técnico'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai_log.outcome_detail.r1')));
      await tester.pumpAndSettle();
      expect(find.text('context deadline exceeded'), findsOneWidget);
    });

    testWidgets('corrida FAILED sin items (falló antes de escribir el log): '
        'el drill pinta el desenlace, no niega la actividad', (tester) async {
      load(
        const <AiLogEntry>[],
        drill: true,
        run: outcome(status: 'FAILED', error: 'context deadline exceeded'),
      );
      await pump(tester);
      expect(find.byKey(const Key('ai_log.outcome_only')), findsOneWidget);
      // Encabezado-resumen + título del nodo: el mismo copy, dos lugares.
      expect(
        find.text('La corrida excedió el tiempo límite · ~42s'),
        findsWidgets,
      );
      expect(find.byKey(const Key('ai_log.empty')), findsNothing);
      // El crudo sigue plegado como detalle técnico.
      expect(find.text('context deadline exceeded'), findsNothing);
      await tester.tap(find.byKey(const Key('ai_log.outcome_detail.drill')));
      await tester.pumpAndSettle();
      expect(find.text('context deadline exceeded'), findsOneWidget);
    });

    testWidgets('corrida directa a la respuesta (sin pasos de proceso): el '
        'resumen honesto es «Respondió directo»', (tester) async {
      load(
        <AiLogEntry>[
          e(2, content: 'Hola, ¿en qué ayudo?'),
          e(1, role: AiLogRole.user, content: 'hola'),
        ],
        drill: true,
        run: outcome(),
      );
      await pump(tester);
      expect(find.textContaining('Respondió directo'), findsOneWidget);
    });

    testWidgets('corrida FAILED sin pasos de proceso: el resumen es «Falló '
        'la corrida»', (tester) async {
      load(
        <AiLogEntry>[
          e(2, content: 'lo intento…'),
          e(1, role: AiLogRole.user, content: 'hola'),
        ],
        drill: true,
        run: outcome(status: 'FAILED', error: 'boom'),
      );
      await pump(tester);
      expect(find.textContaining('Falló la corrida'), findsOneWidget);
    });

    testWidgets('sin run{} (corrida vieja o en curso) no se inventa el '
        'cierre', (tester) async {
      load(runDesc(), drill: true);
      await pump(tester);
      expect(find.textContaining('Corrida completada'), findsNothing);
      expect(find.textContaining('Falló'), findsNothing);
    });

    testWidgets('el desenlace se fija DESPUÉS del cap: «+N pasos más» y el '
        'cierre conviven', (tester) async {
      // 10 tools ⇒ cap persistido por la cabeza (7 + «+3 pasos más») y el
      // desenlace al final, jamás recortado.
      load(
        <AiLogEntry>[
          for (var i = 10; i >= 1; i--)
            e(i + 1, role: AiLogRole.tool, toolName: 'tool_$i'),
          e(1, role: AiLogRole.user, content: 'dale'),
        ],
        drill: true,
        run: outcome(),
      );
      await pump(tester);

      expect(find.text('+3 pasos más'), findsOneWidget);
      expect(find.text('Corrida completada · ~42s'), findsOneWidget);
    });
  });

  testWidgets('cursor presente → botón "Cargar anteriores" dispara more', (
    tester,
  ) async {
    load(<AiLogEntry>[
      e(1, role: AiLogRole.user, content: 'hola'),
    ], nextBefore: 1);
    await pump(tester);

    await tester.tap(find.byKey(const Key('ai_log.load_more')));
    verify(() => bloc.add(const AiLogMoreRequested())).called(1);
  });

  testWidgets('vacío → copy honesto', (tester) async {
    load(const <AiLogEntry>[]);
    await pump(tester);
    expect(find.byKey(const Key('ai_log.empty')), findsOneWidget);
  });

  // ── header de tokens/costo de la corrida ─────────────────────────────
  group('header de tokens de la corrida', () {
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

  // ── dispatch del turno role=tool por toolName (render plano legacy) ──
  group('render de turnos tool por toolName', () {
    const analysisWire =
        '{"kind":"chat_analysis","summary":"resumen X","facts":[],'
        '"sentiment":"","timeline":[],"truncated":false}';
    const subagentWire =
        '{"status":"completed","summary":"hice la tarea","result":"r"}';

    void loadTool(AiLogEntry entry) => load(<AiLogEntry>[entry]);

    testWidgets('analyze_chat con envelope válido → AnalysisCard, no el blob', (
      tester,
    ) async {
      loadTool(
        e(
          5,
          runId: '',
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
      loadTool(
        e(
          6,
          runId: '',
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
      loadTool(
        e(
          7,
          runId: '',
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
      // tarjeta de «Actividad previa» MÁS la del blob (2).
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
      loadTool(
        e(
          8,
          runId: '',
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
      loadTool(
        e(
          9,
          runId: '',
          role: AiLogRole.tool,
          toolName: 'search_messages',
          content: '[]',
        ),
      );
      await pump(tester);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tool sin icono propio → icono por defecto', (tester) async {
      loadTool(
        e(
          10,
          runId: '',
          role: AiLogRole.tool,
          toolName: 'apply_label',
          content: 'ok',
        ),
      );
      await pump(tester);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });
  });

  testWidgets('la lista reserva el inset inferior del sistema en su padding', (
    tester,
  ) async {
    load(<AiLogEntry>[e(1, role: AiLogRole.user, content: 'hola')]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: const EdgeInsets.only(bottom: 34)),
              child: BlocProvider<AiLogBloc>.value(
                value: bloc,
                child: const AiLogPage(),
              ),
            ),
          ),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.padding?.resolve(TextDirection.ltr).bottom, AppTokens.sp4 + 34);
  });
}
