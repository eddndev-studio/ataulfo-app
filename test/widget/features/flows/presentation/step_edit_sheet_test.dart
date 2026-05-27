import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:agentic/features/flows/presentation/widgets/step_edit_sheet.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const FlowStepsAddRequested(
        content: '',
        delayMs: 0,
        jitterPct: 0,
        aiOnly: false,
      ),
    );
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
  });

  Widget host({fdom.Step? editing}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowStepsBloc>.value(
      value: bloc,
      child: Scaffold(
        body: SafeArea(child: StepEditSheet(editing: editing)),
      ),
    ),
  );

  const editingStep = fdom.Step(
    id: 's1',
    flowId: 'f1',
    type: fdom.StepType.text,
    order: 0,
    content: 'Hola original',
    mediaRef: '',
    metadataJson: '{}',
    delayMs: 1500,
    jitterPct: 10,
    aiOnly: true,
  );

  group('StepEditSheet (Add mode)', () {
    testWidgets('renderiza título "Nuevo paso", campo content y sliders', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(find.text('Nuevo paso'), findsOneWidget);
      expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.delay_slider')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.jitter_slider')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.ai_only_switch')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
    });

    testWidgets(
      'submit con content vacío es no-op (no dispatcha AddRequested)',
      (tester) async {
        await tester.pumpWidget(host());

        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets(
      'submit con content válido dispatcha AddRequested con los valores ingresados',
      (tester) async {
        await tester.pumpWidget(host());

        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'Hola {{name}}',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verify(
          () => bloc.add(
            const FlowStepsAddRequested(
              content: 'Hola {{name}}',
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'estado Mutating bloquea el submit (tap no dispatcha AddRequested)',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const FlowStepsMutating(<fdom.Step>[]));

        await tester.pumpWidget(host());
        await tester.enterText(find.byKey(const Key('step_edit.content')), 'X');
        await tester.pump();
        await tester.tap(find.byKey(const Key('step_edit.submit')));
        await tester.pump();

        verifyNever(() => bloc.add(any()));
      },
    );

    testWidgets(
      'MutationFailed con InvalidStepFailure muestra copy específico',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const FlowStepsMutationFailed(
            <fdom.Step>[],
            FlowsInvalidStepFailure(),
          ),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('step_edit.error.invalid_step')),
          findsOneWidget,
        );
      },
    );

    testWidgets('MutationFailed con NetworkFailure muestra copy de red', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const FlowStepsMutationFailed(<fdom.Step>[], FlowsNetworkFailure()),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('step_edit.error.network')), findsOneWidget);
    });
  });

  group('StepEditSheet (Edit mode)', () {
    setUpAll(() {
      registerFallbackValue(
        const FlowStepsUpdateRequested(stepId: 's', content: 'x'),
      );
    });

    testWidgets('renderiza título "Editar paso" y prefilling del content', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: editingStep));

      expect(find.text('Editar paso'), findsOneWidget);
      // El TextField está prefilled con el content del editing.
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('step_edit.content')),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.controller?.text, 'Hola original');
    });

    testWidgets('edit con cambios dispatcha UpdateRequested con only-changed', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: editingStep));
      // Cambia solo el content; los sliders/switch quedan iguales.
      await tester.enterText(
        find.byKey(const Key('step_edit.content')),
        'Hola edited',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verify(
        () => bloc.add(
          const FlowStepsUpdateRequested(stepId: 's1', content: 'Hola edited'),
        ),
      ).called(1);
    });

    testWidgets('edit sin cambios es no-op (no dispatcha UpdateRequested)', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: editingStep));
      // Sin tocar nada — sólo tap submit.
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('edit con content vacío es no-op (gate del trim().isEmpty)', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: editingStep));
      await tester.enterText(find.byKey(const Key('step_edit.content')), '   ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('step_edit.submit')));
      await tester.pump();

      verifyNever(() => bloc.add(any()));
    });

    testWidgets(
      'modo edit muestra botón eliminar; tap → confirm → DeleteRequested',
      (tester) async {
        registerFallbackValue(const FlowStepsDeleteRequested('s'));

        await tester.pumpWidget(host(editing: editingStep));
        expect(find.byKey(const Key('step_edit.delete')), findsOneWidget);

        await tester.tap(find.byKey(const Key('step_edit.delete')));
        await tester.pumpAndSettle();

        // El dialog de confirmación aparece.
        expect(
          find.byKey(const Key('step_edit.delete_confirm')),
          findsOneWidget,
        );
        // Tap en confirmar.
        await tester.tap(find.byKey(const Key('step_edit.delete_confirm.ok')));
        await tester.pumpAndSettle();

        verify(() => bloc.add(const FlowStepsDeleteRequested('s1'))).called(1);
      },
    );

    testWidgets('modo add no muestra botón eliminar', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byKey(const Key('step_edit.delete')), findsNothing);
    });

    testWidgets('tap en cancelar del dialog NO dispatcha DeleteRequested', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: editingStep));
      await tester.tap(find.byKey(const Key('step_edit.delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('step_edit.delete_confirm.cancel')),
      );
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
    });
  });
}
