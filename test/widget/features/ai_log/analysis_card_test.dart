import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/features/ai_log/domain/entities/chat_analysis_envelope.dart';
import 'package:ataulfo/features/ai_log/presentation/widgets/analysis_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, ChatAnalysisEnvelope env) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(body: AnalysisCard(envelope: env)),
      ),
    );
  }

  testWidgets('pinta resumen, hechos, sentimiento y línea de tiempo', (
    tester,
  ) async {
    await pump(
      tester,
      const ChatAnalysisEnvelope(
        summary: 'el cliente quiere mayoreo',
        facts: <String>['compra recurrente', 'paga a 30 días'],
        sentiment: 'positivo',
        timeline: <ChatAnalysisTimelineEvent>[
          ChatAnalysisTimelineEvent(at: '10:00', event: 'saluda'),
        ],
        truncated: false,
      ),
    );

    // La tarjeta es un AppCard del kit (variante outline), no un Material
    // con borde ad-hoc: misma geometría que el resto del design system.
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.text('el cliente quiere mayoreo'), findsOneWidget);
    expect(find.textContaining('compra recurrente'), findsOneWidget);
    expect(find.textContaining('paga a 30 días'), findsOneWidget);
    expect(find.textContaining('saluda'), findsOneWidget);
    expect(find.textContaining('positivo'), findsOneWidget);
  });

  testWidgets('truncated=true muestra la marca; false no', (tester) async {
    await pump(
      tester,
      const ChatAnalysisEnvelope(
        summary: 's',
        facts: <String>[],
        sentiment: '',
        timeline: <ChatAnalysisTimelineEvent>[],
        truncated: true,
      ),
    );
    expect(find.byKey(const Key('analysis_card.truncated')), findsOneWidget);

    await pump(
      tester,
      const ChatAnalysisEnvelope(
        summary: 's',
        facts: <String>[],
        sentiment: '',
        timeline: <ChatAnalysisTimelineEvent>[],
        truncated: false,
      ),
    );
    expect(find.byKey(const Key('analysis_card.truncated')), findsNothing);
  });

  testWidgets('campos vacíos → no pinta secciones vacías', (tester) async {
    await pump(
      tester,
      const ChatAnalysisEnvelope(
        summary: 'sólo resumen',
        facts: <String>[],
        sentiment: '',
        timeline: <ChatAnalysisTimelineEvent>[],
        truncated: false,
      ),
    );
    expect(find.text('sólo resumen'), findsOneWidget);
    expect(find.text('Hechos'), findsNothing);
    expect(find.text('Línea de tiempo'), findsNothing);
    expect(find.text('Sentimiento'), findsNothing);
  });
}
