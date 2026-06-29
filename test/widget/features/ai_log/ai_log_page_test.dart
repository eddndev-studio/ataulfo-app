import 'package:ataulfo/core/design/app_design_theme.dart';
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
  int totalTokens = 0,
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
  promptTokens: 0,
  completionTokens: 0,
  totalTokens: totalTokens,
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

  testWidgets('pinta la corrida: cliente, razonamiento colapsable, tool '
      'chip, resultado y tokens', (tester) async {
    when(() => bloc.state).thenReturn(
      AiLogLoaded(
        entries: <AiLogEntry>[
          e(4, content: 'Abrimos 9-18.', model: 'm1', totalTokens: 15),
          e(3, role: AiLogRole.tool, toolName: 'read_doc', content: 'L-V 9-18'),
          e(
            2,
            reasoning: 'consulto el doc de horarios',
            toolCalls: const <AiToolCall>[
              AiToolCall(id: 'c0', name: 'read_doc', argumentsJson: '{}'),
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
    expect(find.text('⚙ read_doc'), findsOneWidget);
    expect(find.byKey(const Key('ai_log.reasoning.2')), findsOneWidget);
    expect(find.byKey(const Key('ai_log.tool_result.3')), findsOneWidget);
    expect(find.text('15 tokens'), findsOneWidget);
    // El razonamiento arranca colapsado; al expandir aparece el texto.
    expect(find.text('consulto el doc de horarios'), findsNothing);
    await tester.tap(find.byKey(const Key('ai_log.reasoning.2')));
    await tester.pumpAndSettle();
    expect(find.text('consulto el doc de horarios'), findsOneWidget);
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
