import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/media_names_cubit.dart';
import 'package:ataulfo/features/flows/presentation/widgets/flow_steps_section.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockMediaNamesCubit extends MockCubit<MediaNamesState>
    implements MediaNamesCubit {}

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

fdom.Step _text(String id, int order) => fdom.Step(
  id: id,
  flowId: 'f1',
  type: fdom.StepType.text,
  order: order,
  content: 'msg $id',
  mediaRef: '',
  metadataJson: '{}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

/// CT en order 0 apuntando a `a` (match) y `b` (else) — cualquier drop que
/// deje a `a` o `b` por encima del condicional viola forward-only.
fdom.Step _ct(int order) => fdom.Step(
  id: 'ct',
  flowId: 'f1',
  type: fdom.StepType.conditionalTime,
  order: order,
  content: '',
  mediaRef: '',
  metadataJson:
      '{"tz":"UTC","windows":[{"days":[1],"from":"09:00","to":"18:00"}],'
      '"on_match_step_id":"a","on_else_step_id":"b"}',
  delayMs: 1000,
  jitterPct: 0,
  aiOnly: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowStepsReorderRequested(<String>[]));
  });

  late _MockStepsBloc bloc;
  late _MockMediaNamesCubit mediaNames;
  late _MockLabelsBloc labels;

  setUp(() {
    bloc = _MockStepsBloc();
    mediaNames = _MockMediaNamesCubit();
    labels = _MockLabelsBloc();
    when(() => mediaNames.state).thenReturn(const MediaNamesState());
    when(() => labels.state).thenReturn(const LabelsLoading());
  });

  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<FlowStepsBloc>.value(value: bloc),
              BlocProvider<MediaNamesCubit>.value(value: mediaNames),
              BlocProvider<LabelsBloc>.value(value: labels),
            ],
            child: const FlowStepsSection(),
          ),
        ),
      ),
    );
  }

  group('forward-only prevenido en el drag (validación client-side)', () {
    testWidgets(
      'un drop que deja un destino por ENCIMA del condicional no dispatcha '
      'reorder y avisa localmente — sin round-trip',
      (tester) async {
        when(() => bloc.state).thenReturn(
          FlowStepsLoaded(<fdom.Step>[_ct(0), _text('a', 1), _text('b', 2)]),
        );
        await pumpSection(tester);

        // Arrastra `a` (destino) por encima del CT: orden propuesto
        // [a, ct, b] — el condicional quedaría apuntando hacia atrás.
        await tester.timedDrag(
          find.byKey(const Key('flow_detail.step_card.drag_handle.a')),
          const Offset(0, -400),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(any()));
        expect(
          find.text(
            'Ese orden dejaría un condicional apuntando hacia atrás. '
            'Sus destinos deben quedar después del condicional.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('un drop válido dispatcha el reorder como siempre', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        FlowStepsLoaded(<fdom.Step>[_ct(0), _text('a', 1), _text('b', 2)]),
      );
      await pumpSection(tester);

      // Intercambia los dos destinos entre sí: [ct, b, a] sigue forward.
      await tester.timedDrag(
        find.byKey(const Key('flow_detail.step_card.drag_handle.b')),
        const Offset(0, -120),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();

      verify(
        () =>
            bloc.add(const FlowStepsReorderRequested(<String>['ct', 'b', 'a'])),
      ).called(1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
