import 'package:agentic/core/design/app_design_theme.dart';
import 'package:agentic/core/design/tokens.dart';
import 'package:agentic/core/design/widgets/app_button.dart';
import 'package:agentic/core/design/widgets/app_pill.dart';
import 'package:agentic/features/flows/domain/entities/flow.dart' as flows;
import 'package:agentic/features/flows/domain/entities/step.dart' as fdom;
import 'package:agentic/features/flows/domain/failures/flows_failure.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:agentic/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:agentic/features/flows/presentation/pages/flow_detail_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

const _flow = flows.Flow(
  id: 'f1',
  templateId: 't1',
  name: 'Bienvenida',
  isActive: true,
  version: 3,
  cooldownMs: 0,
  usageLimit: 0,
  excludesFlows: <String>[],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const FlowDetailLoadRequested());
    registerFallbackValue(const FlowStepsLoadRequested());
  });

  late _MockDetailBloc detailBloc;
  late _MockStepsBloc stepsBloc;

  setUp(() {
    detailBloc = _MockDetailBloc();
    stepsBloc = _MockStepsBloc();
    when(() => detailBloc.state).thenReturn(const FlowDetailLoading());
    when(() => stepsBloc.state).thenReturn(const FlowStepsLoading());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FlowDetailBloc>.value(value: detailBloc),
        BlocProvider<FlowStepsBloc>.value(value: stepsBloc),
      ],
      child: const Scaffold(body: FlowDetailPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => detailBloc.state).thenReturn(const FlowDetailLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded muestra header con nombre + pill version + pill status', (
    tester,
  ) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

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
        cooldownMs: 0,
        usageLimit: 0,
        excludesFlows: <String>[],
      );
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(paused, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
      expect(find.widgetWithText(AppPill, 'Activo'), findsNothing);
    },
  );

  testWidgets('FlowStepsLoaded vacío muestra empty state', (tester) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flow_detail.steps.empty')), findsOneWidget);
  });

  testWidgets(
    'FlowStepsLoaded con items muestra una card por step con humanización del type',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
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

      expect(find.byKey(const Key('flow_detail.step_card.s1')), findsOneWidget);
      expect(find.byKey(const Key('flow_detail.step_card.s2')), findsOneWidget);
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Imagen'), findsOneWidget);
      expect(find.text('Hola {{name}}'), findsOneWidget);
      expect(find.textContaining('example.com/x.png'), findsWidgets);
      expect(find.widgetWithText(AppPill, 'Solo IA'), findsOneWidget);
    },
  );

  testWidgets(
    'cada StepCard muestra un AppPill con el label humanizado del tipo',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'Hola',
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
            content: '',
            mediaRef: 'https://x/y.png',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 's3',
            flowId: 'f1',
            type: fdom.StepType.ptt,
            order: 2,
            content: '',
            mediaRef: 'https://x/y.ogg',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppPill, 'Texto'), findsOneWidget);
      expect(find.widgetWithText(AppPill, 'Imagen'), findsOneWidget);
      expect(find.widgetWithText(AppPill, 'PTT'), findsOneWidget);
    },
  );

  testWidgets(
    'CONDITIONAL_TIME card muestra TZ, días/horario, y destinos onMatch/onElse',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'Hola',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 'ct',
            flowId: 'f1',
            type: fdom.StepType.conditionalTime,
            order: 1,
            content: '',
            mediaRef: '',
            metadataJson:
                '{"tz":"America/Mexico_City","windows":[{"days":[1,2,3,4,5],'
                '"from":"09:00","to":"18:00"}],"on_match_order":2,'
                '"on_else_order":3}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      // TZ visible.
      expect(find.textContaining('America/Mexico_City'), findsOneWidget);
      // Ventana visible — días L-V (uiIndex 0..4) + 09:00-18:00.
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
      // Destinos: "Paso #3" y "Paso #4" (order+1 humanizado).
      expect(find.textContaining('Paso #3'), findsOneWidget);
      expect(find.textContaining('Paso #4'), findsOneWidget);
    },
  );

  testWidgets(
    'CONDITIONAL_TIME con metadataJson corrupto cae al fallback honesto',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 'ct-bad',
            flowId: 'f1',
            type: fdom.StepType.conditionalTime,
            order: 0,
            content: '',
            mediaRef: '',
            metadataJson: '{"tz":"","windows":[]}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.step.ct_corrupt')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'FlowStepsLoading muestra spinner inline en el tab Pasos (header sigue visible)',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(const FlowStepsLoading());

      await tester.pumpWidget(host());

      // Header sigue visible.
      expect(find.text('Bienvenida'), findsOneWidget);
      // Y aparece un spinner en el tab Pasos.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'FlowStepsFailed(no NotFound) muestra mensaje genérico + tap Reintentar dispatcha LoadRequested',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.steps.error.generic')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();
      verify(() => stepsBloc.add(const FlowStepsLoadRequested())).called(1);
    },
  );

  testWidgets(
    'FlowStepsFailed(NotFound) muestra mensaje terminal sin Reintentar',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsFailed(FlowsNotFoundFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.steps.error.not_found')),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Reintentar'), findsNothing);
    },
  );

  testWidgets(
    'FlowDetailFailed(NotFound) muestra mensaje terminal sin Reintentar',
    (tester) async {
      when(
        () => detailBloc.state,
      ).thenReturn(const FlowDetailFailed(FlowsNotFoundFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.error.not_found')),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Reintentar'), findsNothing);
    },
  );

  testWidgets(
    'FlowDetailFailed(no NotFound) muestra mensaje genérico + Reintentar dispatcha LoadRequested al FlowDetailBloc',
    (tester) async {
      when(
        () => detailBloc.state,
      ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.error.generic')),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
      await tester.pump();
      verify(() => detailBloc.add(const FlowDetailLoadRequested())).called(1);
    },
  );

  testWidgets(
    'Loaded monta TabBar con 3 tabs: Pasos / Disparadores / Configuración',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

      await tester.pumpWidget(host());

      expect(find.byType(TabBar), findsOneWidget);
      final tabBar = find.byType(TabBar);
      expect(
        find.descendant(of: tabBar, matching: find.text('Pasos')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tabBar, matching: find.text('Disparadores')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tabBar, matching: find.text('Configuración')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Tap en tab Disparadores muestra placeholder "Próximamente"', (
    tester,
  ) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());
    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Disparadores'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('flow_detail.tab.triggers.coming_soon')),
      findsOneWidget,
    );
  });

  testWidgets('Tap en tab Configuración monta FlowSettingsTab', (tester) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());
    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Configuración'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flow_detail.tab.settings')), findsOneWidget);
    // El form del settings tab debe estar renderizado.
    expect(
      find.byKey(const Key('flow_settings.cooldown.slider')),
      findsOneWidget,
    );
  });

  testWidgets('Loading no monta TabBar', (tester) async {
    when(() => detailBloc.state).thenReturn(const FlowDetailLoading());

    await tester.pumpWidget(host());

    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('Failed no monta TabBar', (tester) async {
    when(
      () => detailBloc.state,
    ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('Tab Pasos muestra botón "Nuevo paso"', (tester) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());

    expect(
      find.byKey(const Key('flow_detail.steps.add_button')),
      findsOneWidget,
    );
  });

  testWidgets('Tap del botón "Nuevo paso" abre el StepEditSheet (modal)', (
    tester,
  ) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('flow_detail.steps.add_button')));
    await tester.pumpAndSettle();

    // El sheet del paso aparece (campo content confirma su presencia;
    // el título "Nuevo paso" choca con el label del botón).
    expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
    expect(find.byKey(const Key('step_edit.delay_slider')), findsOneWidget);
  });

  testWidgets(
    'Loaded con N≥2 steps monta ReorderableListView con drag handle por card',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'A',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 's2',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 1,
            content: 'B',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(
        find.byKey(const Key('flow_detail.step_card.drag_handle.s1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flow_detail.step_card.drag_handle.s2')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Drag de un step dispatcha FlowStepsReorderRequested con ids en orden nuevo',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'A',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 's2',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 1,
            content: 'B',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      await tester.timedDrag(
        find.byKey(const Key('flow_detail.step_card.drag_handle.s1')),
        const Offset(0, 200),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();

      verify(
        () => stepsBloc.add(
          const FlowStepsReorderRequested(<String>['s2', 's1']),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'Loaded con 1 step NO monta ReorderableListView (1 item no tiene reorder)',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'Solo',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      expect(find.byType(ReorderableListView), findsNothing);
      expect(
        find.byKey(const Key('flow_detail.step_card.drag_handle.s1')),
        findsNothing,
      );
      // El card sigue visible para tap → editar.
      expect(find.byKey(const Key('flow_detail.step_card.s1')), findsOneWidget);
    },
  );

  testWidgets(
    'Tap en StepCard abre el StepEditSheet en modo Edit (prefilled)',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.text,
            order: 0,
            content: 'Hola original',
            mediaRef: '',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());
      await tester.tap(find.byKey(const Key('flow_detail.step_card.s1')));
      await tester.pumpAndSettle();

      expect(find.text('Editar paso'), findsOneWidget);
      // Prefilling: el TextField del content tiene el valor del step.
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('step_edit.content')),
          matching: find.byType(TextField),
        ),
      );
      expect(tf.controller?.text, 'Hola original');
    },
  );
}
