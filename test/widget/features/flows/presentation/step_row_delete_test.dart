import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/widgets/step_row.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

/// El borrado de un paso baja una capa: mantener presionada la card ofrece
/// eliminar SIN pasar por el sheet (antes: card → sheet → basura → diálogo).
/// La misma política no contradictoria aplica: un paso que es destino de un
/// condicional no ofrece "Eliminar" — solo el aviso con "Entendido".
void main() {
  const step = fdom.Step(
    id: 's1',
    flowId: 'f1',
    type: fdom.StepType.text,
    order: 0,
    content: 'Hola',
    mediaRef: '',
    metadataJson: '{}',
    delayMs: 1000,
    jitterPct: 0,
    aiOnly: false,
  );

  // Un condicional que apunta a s1: el borrado de s1 está condenado al 409.
  const ct = fdom.Step(
    id: 's-ct',
    flowId: 'f1',
    type: fdom.StepType.conditionalTime,
    order: 1,
    content: '',
    mediaRef: '',
    metadataJson:
        '{"tz":"UTC","windows":[{"days":[1],"from":"08:00","to":"12:00"}],'
        '"on_match_step_id":"s1","on_else_step_id":"s2"}',
    delayMs: 1000,
    jitterPct: 0,
    aiOnly: false,
  );

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    registerFallbackValue(const FlowStepsDeleteRequested('s'));
    when(() => bloc.state).thenReturn(const FlowStepsLoaded(<fdom.Step>[step]));
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: BlocProvider<FlowStepsBloc>.value(
          value: bloc,
          child: Scaffold(
            body: StepRow(step: step, onTap: () {}),
          ),
        ),
      ),
    );
  }

  testWidgets('long-press en la card → confirmar → dispatcha DeleteRequested', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.longPress(find.byKey(const Key('flow_detail.step_card.s1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('step_edit.delete_confirm.ok')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('step_edit.delete_confirm.ok')));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const FlowStepsDeleteRequested('s1'))).called(1);
  });

  testWidgets('long-press + cancelar NO dispatcha nada', (tester) async {
    await pumpCard(tester);

    await tester.longPress(find.byKey(const Key('flow_detail.step_card.s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('step_edit.delete_confirm.cancel')));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any()));
  });

  testWidgets(
    'paso referenciado por un condicional: long-press muestra el aviso con '
    'CTA única "Entendido" y no ofrece Eliminar',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[step, ct]));
      await pumpCard(tester);

      await tester.longPress(find.byKey(const Key('flow_detail.step_card.s1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('step_edit.delete_confirm.ok')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('step_edit.delete_blocked.ok')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('step_edit.delete_blocked.ok')));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    },
  );
}
