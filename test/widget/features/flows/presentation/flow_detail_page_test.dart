import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as flows;
import 'package:ataulfo/features/flows/domain/entities/step.dart' as fdom;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_detail_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flow_steps_bloc.dart';
import 'package:ataulfo/features/flows/presentation/bloc/media_names_cubit.dart';
import 'package:ataulfo/features/flows/presentation/pages/flow_detail_page.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/triggers/presentation/widgets/flow_triggers_tab.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

class _MockMediaNamesCubit extends MockCubit<MediaNamesState>
    implements MediaNamesCubit {}

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
  late _MockTriggersRepo triggersRepo;
  late _MockLabelsRepo labelsRepo;
  late _MockMediaNamesCubit mediaNamesCubit;

  setUp(() {
    detailBloc = _MockDetailBloc();
    stepsBloc = _MockStepsBloc();
    triggersRepo = _MockTriggersRepo();
    labelsRepo = _MockLabelsRepo();
    mediaNamesCubit = _MockMediaNamesCubit();
    when(() => detailBloc.state).thenReturn(const FlowDetailLoading());
    when(() => stepsBloc.state).thenReturn(const FlowStepsLoading());
    // Resolutor de nombres por default vacío (sin cargar): los pasos
    // multimedia caen a su respaldo (media_filename / cola corta del ref).
    when(() => mediaNamesCubit.state).thenReturn(const MediaNamesState());
    // Mantiene el TriggersBloc (creado lazy por FlowTriggersTab) en
    // Loading sin timers vivos al cerrar el test.
    when(
      () => triggersRepo.listTriggers(any()),
    ).thenAnswer((_) => Completer<List<Trigger>>().future);
    // El LabelsBloc lo crea `_openStepSheet` al abrir el sheet (para el paso
    // LABEL); el catálogo vacío basta para los tests que solo abren el sheet.
    when(() => labelsRepo.listLabels()).thenAnswer((_) async => <Label>[]);
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<TriggersRepository>.value(value: triggersRepo),
        RepositoryProvider<LabelsRepository>.value(value: labelsRepo),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<FlowDetailBloc>.value(value: detailBloc),
          BlocProvider<FlowStepsBloc>.value(value: stepsBloc),
          BlocProvider<MediaNamesCubit>.value(value: mediaNamesCubit),
        ],
        child: const Scaffold(body: FlowDetailPage()),
      ),
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
      // Sin media_filename guardado, el paso multimedia cae a la cola corta del
      // ref (último segmento), nunca el ref/URL completo.
      expect(find.text('x.png'), findsOneWidget);
      expect(find.textContaining('example.com'), findsNothing);
      expect(find.widgetWithText(AppPill, 'Solo IA'), findsOneWidget);
    },
  );

  testWidgets(
    'StepCard multimedia muestra el nombre del archivo (media_filename) cuando '
    'está guardado; sin él, la cola corta del ref — nunca el ref completo',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's-doc',
            flowId: 'f1',
            type: fdom.StepType.document,
            order: 0,
            content: '',
            mediaRef: 'tenant/org1/media/abc123.pdf',
            metadataJson: '{"media_filename":"Contrato 2026.pdf"}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
          fdom.Step(
            id: 's-img',
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 1,
            content: '',
            mediaRef: 'tenant/org1/media/zzz999.png',
            metadataJson: '{}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );

      await tester.pumpWidget(host());

      // DOCUMENT con media_filename → nombre legible, NUNCA el id/ref del path.
      expect(find.text('Contrato 2026.pdf'), findsOneWidget);
      expect(find.textContaining('abc123'), findsNothing);
      // IMAGE sin media_filename → cola corta del ref BARE, nunca el path del
      // tenant completo.
      expect(find.text('zzz999.png'), findsOneWidget);
      expect(find.textContaining('tenant/org1/media'), findsNothing);
    },
  );

  testWidgets(
    'StepCard multimedia muestra el alias EN VIVO del catálogo (resuelto por '
    'ref), por encima del ref y del media_filename guardado',
    (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's-audio',
            flowId: 'f1',
            type: fdom.StepType.ptt,
            order: 0,
            content: '',
            mediaRef: 'tenant/org1/media/9y1gq8fq8f68g69696wv.ogg',
            // Aunque hubiera un filename guardado, el alias en vivo manda.
            metadataJson: '{"media_filename":"grabacion.ogg"}',
            delayMs: 0,
            jitterPct: 0,
            aiOnly: false,
          ),
        ]),
      );
      // El catálogo resolvió ese ref al alias que el usuario editó en la galería.
      when(() => mediaNamesCubit.state).thenReturn(
        const MediaNamesState(
          namesByRef: <String, String>{
            'tenant/org1/media/9y1gq8fq8f68g69696wv.ogg':
                'Saludo de bienvenida',
          },
          loaded: true,
        ),
      );

      await tester.pumpWidget(host());

      expect(find.text('Saludo de bienvenida'), findsOneWidget);
      expect(find.textContaining('9y1gq8fq8f68g69696wv'), findsNothing);
      expect(find.textContaining('grabacion.ogg'), findsNothing);
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

  testWidgets('Tap en tab Disparadores monta FlowTriggersTab', (tester) async {
    when(() => detailBloc.state).thenReturn(
      const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
    );
    when(
      () => stepsBloc.state,
    ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

    await tester.pumpWidget(host());
    // Sanity: el shell Loaded rendea el header del flow.
    expect(find.text('Bienvenida'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Disparadores'),
      ),
    );
    // Avanza la animación del TabController por frames cortos sin
    // entrar al loop infinito de pumpAndSettle (el spinner del body
    // nunca se detiene). 100ms × 5 = 500ms cubre la transición
    // estándar de TabBarView (~300ms).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // El tab está montado: el FlowTriggersTab es child del TabBarView
    // y el body construye su TriggersBloc; la mock-repo nunca completa
    // ⇒ estado Loading + spinner con key flow_triggers.loading.
    expect(find.byType(FlowTriggersTab), findsOneWidget);
    expect(find.byKey(const Key('flow_triggers.loading')), findsOneWidget);
    expect(
      find.byKey(const Key('flow_detail.tab.triggers.coming_soon')),
      findsNothing,
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

  testWidgets(
    'Tap en StepCard multimedia abre el sheet con "Cambiar" interactivo '
    '(el host de producción cablea el picker también al editar)',
    (tester) async {
      // Pinea el callsite real: _openStepSheet pasa pickMediaRef sin gatear
      // por modo. Los tests del sheet inyectan el callback a mano, así que
      // sólo aquí se verifica que la edición de multimedia nace interactiva
      // en producción. Si alguien volviera a anular el picker al editar, el
      // botón "Cambiar" desaparecería y este expect caería.
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(() => stepsBloc.state).thenReturn(
        const FlowStepsLoaded(<fdom.Step>[
          fdom.Step(
            id: 's1',
            flowId: 'f1',
            type: fdom.StepType.image,
            order: 0,
            content: 'caption',
            mediaRef: 'tenant/org1/media/orig.png',
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
      expect(find.byKey(const Key('step_edit.media_selected')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.media_change')), findsOneWidget);
    },
  );
}
