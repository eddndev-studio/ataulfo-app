import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/features/ai_log/domain/entities/subagent_outcome_envelope.dart';
import 'package:ataulfo/features/ai_log/presentation/widgets/subagent_outcome_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, SubagentOutcomeEnvelope env) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(body: SubagentOutcomeCard(envelope: env)),
      ),
    );
  }

  const resultKey = Key('subagent_outcome_card.result');

  testWidgets('completed con summary y result → ambos visibles (result al '
      'expandir)', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'completed',
        summary: 'encontré 3 facturas',
        result: 'detalle largo del subagente',
        reason: '',
      ),
    );

    // Tarjeta y bloque de detalle son AppCard del kit (outline), no
    // Materiales con borde ad-hoc.
    expect(find.byType(AppCard), findsNWidgets(2));
    expect(find.text('encontré 3 facturas'), findsOneWidget);
    expect(find.byKey(resultKey), findsOneWidget);
    expect(find.textContaining('detalle largo del subagente'), findsNothing);
    await tester.tap(find.byKey(resultKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('detalle largo del subagente'), findsOneWidget);
  });

  testWidgets(
    'completed con summary VACÍO → sólo result, tarjeta no en blanco',
    (tester) async {
      await pump(
        tester,
        const SubagentOutcomeEnvelope(
          status: 'completed',
          summary: '',
          result: 'sólo el detalle',
          reason: '',
        ),
      );

      // No queda en blanco: la cabecera con el estado sigue presente.
      expect(find.text('Completado'), findsOneWidget);
      expect(find.byKey(resultKey), findsOneWidget);
    },
  );

  testWidgets('status-only completed (sin summary ni result) → cabecera, sin '
      'secciones, sin crash', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'completed',
        summary: '',
        result: '',
        reason: '',
      ),
    );

    expect(find.text('Completado'), findsOneWidget);
    expect(find.byKey(resultKey), findsNothing);
  });

  testWidgets('failed → reason con icono de error, sin sección de result', (
    tester,
  ) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'failed',
        summary: '',
        result: '',
        reason: 'el proveedor falló',
      ),
    );

    expect(find.text('el proveedor falló'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byKey(resultKey), findsNothing);
  });

  testWidgets('blocked → reason visible', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'blocked',
        summary: '',
        result: '',
        reason: 'invalid_input',
      ),
    );

    expect(find.text('invalid_input'), findsOneWidget);
  });

  testWidgets('completed con summary presente + result AUSENTE → summary '
      'visible, sin bloque de detalle', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'completed',
        summary: 'hecho',
        result: '',
        reason: '',
      ),
    );

    expect(find.text('hecho'), findsOneWidget);
    expect(find.byKey(resultKey), findsNothing);
  });

  // Guardas isCompleted: summary/result sólo son significativos en completed;
  // un dato malformado con failed/blocked + summary/result NO debe pintarlos
  // como si fuera un éxito (mata la mutación que quita `isCompleted &&`).
  testWidgets('failed con summary no-vacío (malformado) → NO pinta summary, '
      'sí el reason', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'failed',
        summary: 'no debería verse',
        result: '',
        reason: 'motivo real',
      ),
    );

    expect(find.text('no debería verse'), findsNothing);
    expect(find.text('motivo real'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('blocked con result no-vacío (malformado) → NO pinta el bloque '
      'de detalle', (tester) async {
    await pump(
      tester,
      const SubagentOutcomeEnvelope(
        status: 'blocked',
        summary: '',
        result: 'tampoco debería verse',
        reason: 'bloqueado',
      ),
    );

    expect(find.byKey(resultKey), findsNothing);
    expect(find.text('bloqueado'), findsOneWidget);
  });
}
