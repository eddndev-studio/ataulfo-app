import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_pill.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as flows;
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:agentic/features/flows/presentation/pages/flow_detail_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

const _flow = flows.Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 3,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailLoadRequested());
  });

  late _MockBloc bloc;

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const FlowDetailLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<FlowDetailBloc>.value(
      value: bloc,
      child: const Scaffold(body: FlowDetailPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const FlowDetailLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded muestra header con nombre + pill version + pill status',
      (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowDetailLoaded(_flow, <fdom.Step>[]));

    await tester.pumpWidget(host());

    expect(find.text('Bienvenida'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'v3'), findsOneWidget);
    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
  });

  testWidgets(
    'Loaded(isActive=false) muestra pill Pausado en lugar de Activo',
    (tester) async {
      const paused = flows.Flow(
        id: 'f1',
        templateId: 't1',
        name: 'Off',
        isActive: false,
        version: 1,
      );
      when(
        () => bloc.state,
      ).thenReturn(const FlowDetailLoaded(paused, <fdom.Step>[]));

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
      expect(find.widgetWithText(AppPill, 'Activo'), findsNothing);
    },
  );

  testWidgets('Loaded con steps vacíos muestra empty state', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowDetailLoaded(_flow, <fdom.Step>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_detail.steps.empty')), findsOneWidget);
  });

  testWidgets(
    'Loaded con steps muestra una card por step con humanización del type',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'Hola {{name}}',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 's2',
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 1,
            content: 'caption',
            mediaRef: 'https://example.com/x.png',
            metadataJson: '{}',
            delayMs: 500,
            jitterPct: 10,
            aiOnly: true,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.step_card.s1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flow_detail.step_card.s2')),
        findsOneWidget,
      );
      // Humanización del type (Texto / Imagen).
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Imagen'), findsOneWidget);
      // Content del TEXT step.
      expect(find.text('Hola {{name}}'), findsOneWidget);
      // mediaRef del IMAGE step (truncado o completo según logic).
      expect(
        find.textContaining('example.com/x.png'),
        findsWidgets,
      );
      // Pill aiOnly visible sólo para s2.
      expect(find.widgetWithText(AppPill, 'Solo IA'), findsOneWidget);
    },
  );

  testWidgets('Failed(NotFound) muestra mensaje terminal sin Reintentar',
      (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const FlowDetailFailed(FlowsNotFoundFailure()));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('flow_detail.error.not_found')),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsNothing);
  });

  testWidgets(
    'Failed(no NotFound) muestra mensaje genérico + tap Reintentar dispatcha LoadRequested',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.error.generic')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();
      verify(() => bloc.add(const FlowDetailLoadRequested())).called(1);
    },
  );
}
