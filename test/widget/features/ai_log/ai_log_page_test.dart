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
}
