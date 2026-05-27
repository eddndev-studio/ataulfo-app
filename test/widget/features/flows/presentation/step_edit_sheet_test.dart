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
    when(
      () => bloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowStepsBloc>.value(
      value: bloc,
      child: const Scaffold(body: SafeArea(child: StepEditSheet())),
    ),
  );

  group('StepEditSheet (Add mode)', () {
    testWidgets(
      'renderiza título "Nuevo paso", campo content y sliders',
      (tester) async {
        await tester.pumpWidget(host());

        expect(find.text('Nuevo paso'), findsOneWidget);
        expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.delay_slider')), findsOneWidget);
        expect(
          find.byKey(const Key('step_edit.jitter_slider')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('step_edit.ai_only_switch')), findsOneWidget);
        expect(find.byKey(const Key('step_edit.submit')), findsOneWidget);
      },
    );

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
        await tester.enterText(
          find.byKey(const Key('step_edit.content')),
          'X',
        );
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

    testWidgets(
      'MutationFailed con NetworkFailure muestra copy de red',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const FlowStepsMutationFailed(
            <fdom.Step>[],
            FlowsNetworkFailure(),
          ),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('step_edit.error.network')),
          findsOneWidget,
        );
      },
    );

  });
}
