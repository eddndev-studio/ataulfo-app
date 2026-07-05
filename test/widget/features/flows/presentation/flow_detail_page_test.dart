import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_danger_zone.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
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
import 'package:ataulfo/features/labels/presentation/bloc/labels_bloc.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockDetailBloc extends MockBloc<FlowDetailEvent, FlowDetailState>
    implements FlowDetailBloc {}

class _MockStepsBloc extends MockBloc<FlowStepsEvent, FlowStepsState>
    implements FlowStepsBloc {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

class _MockMediaNamesCubit extends MockCubit<MediaNamesState>
    implements MediaNamesCubit {}

class _MockLabelsBloc extends MockBloc<LabelsEvent, LabelsState>
    implements LabelsBloc {}

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

Trigger _trigger({required String id, String flowId = 'f1'}) => Trigger(
  id: id,
  templateId: 't1',
  flowId: flowId,
  triggerType: TriggerType.text,
  matchType: MatchType.contains,
  keyword: 'hola',
  labelId: '',
  labelAction: null,
  scope: TriggerScope.incoming,
  isActive: true,
  createdAt: DateTime.utc(2026, 6, 10),
  updatedAt: DateTime.utc(2026, 6, 10),
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
  late _MockLabelsBloc labelsBloc;

  setUp(() {
    detailBloc = _MockDetailBloc();
    stepsBloc = _MockStepsBloc();
    triggersRepo = _MockTriggersRepo();
    labelsRepo = _MockLabelsRepo();
    mediaNamesCubit = _MockMediaNamesCubit();
    labelsBloc = _MockLabelsBloc();
    when(() => detailBloc.state).thenReturn(const FlowDetailLoading());
    when(() => stepsBloc.state).thenReturn(const FlowStepsLoading());
    // Catálogo de labels sin cargar por default: los pasos LABEL caen al
    // respaldo (id crudo) salvo en los tests que pueblan el catálogo.
    when(() => labelsBloc.state).thenReturn(const LabelsLoading());
    // Resolutor de nombres por default vacío (sin cargar): los pasos
    // multimedia caen a su respaldo (media_filename / cola corta del ref).
    when(() => mediaNamesCubit.state).thenReturn(const MediaNamesState());
    // Mantiene el TriggersBloc del hub (count de la fila launcher) en
    // Loading sin timers vivos al cerrar el test.
    when(
      () => triggersRepo.listTriggers(any()),
    ).thenAnswer((_) => Completer<List<Trigger>>().future);
    // El LabelsBloc lo crea `_openStepSheet` al abrir el sheet (para el paso
    // LABEL); el catálogo vacío basta para los tests que solo abren el sheet.
    when(() => labelsRepo.listLabels()).thenAnswer((_) async => <Label>[]);
  });

  Widget providers(Widget child) => MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<TriggersRepository>.value(value: triggersRepo),
      RepositoryProvider<LabelsRepository>.value(value: labelsRepo),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FlowDetailBloc>.value(value: detailBloc),
        BlocProvider<FlowStepsBloc>.value(value: stepsBloc),
        BlocProvider<MediaNamesCubit>.value(value: mediaNamesCubit),
        BlocProvider<LabelsBloc>.value(value: labelsBloc),
      ],
      child: child,
    ),
  );

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: providers(const Scaffold(body: FlowDetailPage())),
  );

  /// Host ruteado para las pruebas de navegación del hub: la lista en `/`,
  /// el hub en `/flows/:id` y las dos subpáginas como markers que graban
  /// la uri visitada.
  Widget routedHost({required void Function(String uri) onSubpage}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.push('/flows/f1'),
                  child: const Text('abrir editor'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/flows/:id',
          builder: (_, _) => providers(const Scaffold(body: FlowDetailPage())),
        ),
        GoRoute(
          path: '/flows/:id/triggers',
          builder: (_, st) {
            onSubpage(st.uri.toString());
            return Scaffold(
              appBar: AppBar(),
              body: const Text('subpágina disparadores'),
            );
          },
        ),
        GoRoute(
          path: '/flows/:id/settings',
          builder: (_, st) {
            onSubpage(st.uri.toString());
            return Scaffold(
              appBar: AppBar(),
              body: const Text('subpágina configuración'),
            );
          },
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

  fdom.Step textStep({
    String id = 's1',
    int order = 0,
    String content = 'Hola',
  }) => fdom.Step(
    id: id,
    flowId: 'f1',
    type: fdom.StepType.text,
    order: order,
    content: content,
    mediaRef: '',
    metadataJson: '{}',
    delayMs: 0,
    jitterPct: 0,
    aiOnly: false,
  );

  group('estados del hub', () {
    testWidgets('Loading muestra el indicador canónico', (tester) async {
      when(() => detailBloc.state).thenReturn(const FlowDetailLoading());

      await tester.pumpWidget(host());

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
    });

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
      'FlowDetailFailed(no NotFound) muestra error canónico + Reintentar '
      'dispatcha LoadRequested',
      (tester) async {
        when(
          () => detailBloc.state,
        ).thenReturn(const FlowDetailFailed(FlowsServerFailure()));

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_detail.error.generic')),
          findsOneWidget,
        );
        expect(find.byType(AppErrorState), findsOneWidget);
        await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
        await tester.pump();
        verify(() => detailBloc.add(const FlowDetailLoadRequested())).called(1);
      },
    );

    testWidgets('flujo activo: sin pills en el header (el default calla) y '
        'sin la pill v del contador CAS', (tester) async {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[textStep()]));

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppPill, 'v3'), findsNothing);
      expect(find.widgetWithText(AppPill, 'Activo'), findsNothing);
      expect(find.widgetWithText(AppPill, 'Pausado'), findsNothing);
    });

    testWidgets('flujo pausado: pill Pausado (lo excepcional sí habla)', (
      tester,
    ) async {
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
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[textStep()]));

      await tester.pumpWidget(host());

      expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
    });

    testWidgets('un MutationFailed con el hub al frente avisa con SnackBar', (
      tester,
    ) async {
      final states = StreamController<FlowDetailState>.broadcast();
      addTearDown(states.close);
      whenListen(
        detailBloc,
        states.stream,
        initialState: const FlowDetailLoaded(
          _flow,
          <flows.Flow>[],
          siblingsFailed: false,
        ),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

      await tester.pumpWidget(host());
      states.add(
        const FlowDetailMutationFailed(
          _flow,
          <flows.Flow>[],
          FlowsServerFailure(),
          siblingsFailed: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('anatomía del hub', () {
    setUp(() {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
    });

    testWidgets('no queda TabBar: el hub es content-only', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(TabBarView), findsNothing);
    });

    testWidgets('monta las filas launcher a Disparadores y Configuración', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.link.triggers')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flow_detail.link.settings')),
        findsOneWidget,
      );
      expect(find.text('Disparadores'), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);
    });

    testWidgets('la fila de Disparadores muestra el count del flujo '
        '(filtrado por flowId)', (tester) async {
      when(() => triggersRepo.listTriggers('t1')).thenAnswer(
        (_) async => <Trigger>[
          _trigger(id: 'tr1'),
          _trigger(id: 'tr2'),
          _trigger(id: 'tr3', flowId: 'OTRO'),
        ],
      );

      await tester.pumpWidget(host());
      await tester.pump();

      final link = find.byKey(const Key('flow_detail.link.triggers'));
      expect(
        find.descendant(of: link, matching: find.widgetWithText(AppPill, '2')),
        findsOneWidget,
      );
    });

    testWidgets('cierra con la zona peligrosa: Eliminar flujo → confirm → '
        'dispatcha DeleteRequested', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byType(AppDangerZone), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('flow_detail.danger.delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow_detail.danger.delete')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('flow_detail.delete_confirm')),
        findsOneWidget,
      );
      verifyNever(() => detailBloc.add(const FlowDetailDeleteRequested()));

      await tester.tap(find.byKey(const Key('flow_detail.delete_confirm')));
      await tester.pumpAndSettle();

      verify(() => detailBloc.add(const FlowDetailDeleteRequested())).called(1);
    });

    testWidgets('cancelar el confirm no dispatcha nada', (tester) async {
      await tester.pumpWidget(host());
      await tester.ensureVisible(
        find.byKey(const Key('flow_detail.danger.delete')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flow_detail.danger.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => detailBloc.add(const FlowDetailDeleteRequested()));
    });

    testWidgets('los links y la zona peligrosa siguen visibles aunque los '
        'pasos fallen', (tester) async {
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsFailed(FlowsServerFailure()));

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('flow_detail.steps.error.generic')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('flow_detail.link.triggers')),
        findsOneWidget,
      );
      expect(find.byType(AppDangerZone), findsOneWidget);
    });
  });

  group('navegación del hub', () {
    setUp(() {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));
    });

    testWidgets('tap en Disparadores apila /flows/f1/triggers y al volver '
        'refresca cabecera y count', (tester) async {
      String? visited;
      await tester.pumpWidget(routedHost(onSubpage: (uri) => visited = uri));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir editor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('flow_detail.link.triggers')));
      await tester.pumpAndSettle();

      expect(visited, '/flows/f1/triggers');

      // Al volver, el hub refresca la cabecera (version CAS) y el count.
      await tester.pageBack();
      await tester.pumpAndSettle();
      verify(
        () => detailBloc.add(const FlowDetailRefreshRequested()),
      ).called(1);
      verify(() => triggersRepo.listTriggers('t1')).called(2);
    });

    testWidgets('tap en Configuración apila /flows/f1/settings', (
      tester,
    ) async {
      String? visited;
      await tester.pumpWidget(routedHost(onSubpage: (uri) => visited = uri));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir editor'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('flow_detail.link.settings')));
      await tester.pumpAndSettle();

      expect(visited, '/flows/f1/settings');
    });

    testWidgets('FlowDetailDeleted hace pop de regreso a la lista', (
      tester,
    ) async {
      final states = StreamController<FlowDetailState>.broadcast();
      addTearDown(states.close);
      whenListen(
        detailBloc,
        states.stream,
        initialState: const FlowDetailLoaded(
          _flow,
          <flows.Flow>[],
          siblingsFailed: false,
        ),
      );

      await tester.pumpWidget(routedHost(onSubpage: (_) {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir editor'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDangerZone), findsOneWidget);

      states.add(const FlowDetailDeleted());
      await tester.pumpAndSettle();

      expect(find.text('abrir editor'), findsOneWidget);
      expect(find.byType(AppDangerZone), findsNothing);
    });
  });

  group('listado de pasos', () {
    setUp(() {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
    });

    testWidgets('vacío: AppEmptyState con CTA "Crear el primer paso" que '
        'abre el sheet; el botón Nuevo paso no se duplica', (tester) async {
      when(
        () => stepsBloc.state,
      ).thenReturn(const FlowStepsLoaded(<fdom.Step>[]));

      await tester.pumpWidget(host());

      final empty = find.byKey(const Key('flow_detail.steps.empty'));
      expect(empty, findsOneWidget);
      expect(
        tester.widget(empty),
        isA<AppEmptyState>(),
        reason: 'el vacío es el primitivo canónico del kit',
      );
      expect(
        find.byKey(const Key('flow_detail.steps.add_button')),
        findsNothing,
      );

      await tester.tap(find.text('Crear el primer paso'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
    });

    testWidgets('con pasos muestra el botón "Nuevo paso" que abre el sheet', (
      tester,
    ) async {
      when(
        () => stepsBloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[textStep()]));

      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('flow_detail.steps.add_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('step_edit.content')), findsOneWidget);
      expect(find.byKey(const Key('step_edit.delay_slider')), findsOneWidget);
    });

    testWidgets('FlowStepsLoading muestra spinner inline; los launchers '
        'siguen operables', (tester) async {
      when(() => stepsBloc.state).thenReturn(const FlowStepsLoading());

      await tester.pumpWidget(host());

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(
        find.byKey(const Key('flow_detail.link.settings')),
        findsOneWidget,
      );
    });

    testWidgets(
      'FlowStepsFailed(no NotFound) muestra error canónico + Reintentar '
      'dispatcha LoadRequested',
      (tester) async {
        when(
          () => stepsBloc.state,
        ).thenReturn(const FlowStepsFailed(FlowsServerFailure()));

        await tester.pumpWidget(host());

        final error = find.byKey(const Key('flow_detail.steps.error.generic'));
        expect(error, findsOneWidget);
        expect(tester.widget(error), isA<AppErrorState>());
        await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
        await tester.pump();
        verify(() => stepsBloc.add(const FlowStepsLoadRequested())).called(1);
      },
    );

    testWidgets(
      'FlowStepsFailed(NotFound) muestra mensaje terminal sin Reintentar',
      (tester) async {
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
      'FlowStepsLoaded con items muestra una card por step con humanización '
      'del type',
      (tester) async {
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

        expect(
          find.byKey(const Key('flow_detail.step_card.s1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_detail.step_card.s2')),
          findsOneWidget,
        );
        expect(find.text('Texto'), findsOneWidget);
        expect(find.text('Imagen'), findsOneWidget);
        expect(find.text('Hola {{name}}'), findsOneWidget);
        // Sin media_filename guardado, el paso multimedia cae a la cola corta
        // del ref (último segmento), nunca el ref/URL completo.
        expect(find.text('x.png'), findsOneWidget);
        expect(find.textContaining('example.com'), findsNothing);
        expect(find.widgetWithText(AppPill, 'Solo IA'), findsOneWidget);
      },
    );

    testWidgets(
      'StepCard de un paso manualOnly muestra pill "Solo disparadores"',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          const FlowStepsLoaded(<fdom.Step>[
            fdom.Step(
              id: 's1',
              flowId: 'f1',
              type: fdom.StepType.text,
              order: 0,
              content: 'Solo por disparador',
              mediaRef: '',
              metadataJson: '{}',
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
              manualOnly: true,
            ),
          ]),
        );

        await tester.pumpWidget(host());

        expect(
          find.widgetWithText(AppPill, 'Solo disparadores'),
          findsOneWidget,
        );
        expect(find.widgetWithText(AppPill, 'Solo IA'), findsNothing);
      },
    );

    testWidgets(
      'StepCard multimedia muestra el alias EN VIVO del catálogo (resuelto '
      'por ref), por encima del ref y del media_filename guardado',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          const FlowStepsLoaded(<fdom.Step>[
            fdom.Step(
              id: 's-audio',
              flowId: 'f1',
              type: fdom.StepType.ptt,
              order: 0,
              content: '',
              mediaRef: 'tenant/org1/media/9y1gq8fq8f68g69696wv.ogg',
              metadataJson: '{"media_filename":"grabacion.ogg"}',
              delayMs: 0,
              jitterPct: 0,
              aiOnly: false,
            ),
          ]),
        );
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

    testWidgets('CONDITIONAL_TIME card muestra TZ, días/horario, y destinos '
        'onMatch/onElse', (tester) async {
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

      expect(find.textContaining('America/Mexico_City'), findsOneWidget);
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
      expect(find.textContaining('Paso #3'), findsOneWidget);
      expect(find.textContaining('Paso #4'), findsOneWidget);
    });

    testWidgets(
      'CONDITIONAL_TIME con metadataJson corrupto cae al fallback honesto',
      (tester) async {
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
      'Loaded con N≥2 steps monta ReorderableListView con drag handle por '
      'card',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          FlowStepsLoaded(<fdom.Step>[
            textStep(id: 's1', content: 'A'),
            textStep(id: 's2', order: 1, content: 'B'),
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
      'Drag de un step dispatcha FlowStepsReorderRequested con ids en orden '
      'nuevo',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          FlowStepsLoaded(<fdom.Step>[
            textStep(id: 's1', content: 'A'),
            textStep(id: 's2', order: 1, content: 'B'),
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
      'Loaded con 1 step NO monta ReorderableListView (1 item no tiene '
      'reorder)',
      (tester) async {
        when(
          () => stepsBloc.state,
        ).thenReturn(FlowStepsLoaded(<fdom.Step>[textStep(content: 'Solo')]));

        await tester.pumpWidget(host());

        expect(find.byType(ReorderableListView), findsNothing);
        expect(
          find.byKey(const Key('flow_detail.step_card.drag_handle.s1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('flow_detail.step_card.s1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tap en StepCard abre el StepEditSheet en modo Edit (prefilled)',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          FlowStepsLoaded(<fdom.Step>[textStep(content: 'Hola original')]),
        );

        await tester.pumpWidget(host());
        await tester.tap(find.byKey(const Key('flow_detail.step_card.s1')));
        await tester.pumpAndSettle();

        expect(find.text('Editar paso'), findsOneWidget);
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
        expect(
          find.byKey(const Key('step_edit.media_selected')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('step_edit.media_change')), findsOneWidget);
      },
    );
  });

  group('UX del listado de pasos (barrido)', () {
    fdom.Step labelStep({String id = 's1', int order = 0}) => fdom.Step(
      id: id,
      flowId: 'f1',
      type: fdom.StepType.label,
      order: order,
      content: '',
      mediaRef: '',
      metadataJson: '{"label_id":"L1","action":"ADD"}',
      delayMs: 0,
      jitterPct: 0,
      aiOnly: false,
    );

    setUp(() {
      when(() => detailBloc.state).thenReturn(
        const FlowDetailLoaded(_flow, <flows.Flow>[], siblingsFailed: false),
      );
    });

    testWidgets('paso LABEL muestra el NOMBRE de la etiqueta, no el UUID', (
      tester,
    ) async {
      when(
        () => stepsBloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[labelStep()]));
      when(() => labelsBloc.state).thenReturn(
        const LabelsLoaded(<Label>[
          Label(id: 'L1', name: 'VIP', color: '#FF8800', description: ''),
        ]),
      );

      await tester.pumpWidget(host());

      expect(find.textContaining('VIP', findRichText: true), findsOneWidget);
      expect(find.textContaining('L1', findRichText: true), findsNothing);
    });

    testWidgets('paso LABEL cae al id crudo sólo sin catálogo', (tester) async {
      when(
        () => stepsBloc.state,
      ).thenReturn(FlowStepsLoaded(<fdom.Step>[labelStep()]));
      when(() => labelsBloc.state).thenReturn(const LabelsLoading());

      await tester.pumpWidget(host());

      expect(find.textContaining('L1', findRichText: true), findsOneWidget);
    });

    testWidgets('fallo al reordenar muestra SnackBar (no es silencioso)', (
      tester,
    ) async {
      final seed = FlowStepsLoaded(<fdom.Step>[
        textStep(id: 's0'),
        labelStep(id: 's1', order: 1),
      ]);
      whenListen(
        stepsBloc,
        Stream<FlowStepsState>.fromIterable(<FlowStepsState>[
          FlowStepsMutationFailed(seed.steps, const FlowsNetworkFailure()),
        ]),
        initialState: seed,
      );

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'No se pudo guardar el nuevo orden. Se revirtieron los cambios.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('FlowStepsRefreshing conserva las cards con progreso inline '
        '(el refetch post-mutación nunca sustituye la lista por un spinner)', (
      tester,
    ) async {
      when(() => stepsBloc.state).thenReturn(
        FlowStepsRefreshing(<fdom.Step>[
          textStep(id: 's0'),
          labelStep(id: 's1', order: 1),
        ]),
      );

      await tester.pumpWidget(host());

      expect(find.byKey(const Key('flow_detail.step_card.s0')), findsOneWidget);
      expect(find.byKey(const Key('flow_detail.step_card.s1')), findsOneWidget);
      expect(
        find.byKey(const Key('flow_detail.steps.mutating')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'FlowStepsRefreshFailed conserva las cards + aviso con Reintentar que '
      'dispatcha RefreshRequested (el cambio persistió; nada de Failed '
      'terminal)',
      (tester) async {
        when(() => stepsBloc.state).thenReturn(
          FlowStepsRefreshFailed(<fdom.Step>[
            textStep(id: 's0'),
            labelStep(id: 's1', order: 1),
          ], const FlowsServerFailure()),
        );

        await tester.pumpWidget(host());

        expect(
          find.byKey(const Key('flow_detail.step_card.s0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_detail.step_card.s1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('flow_detail.steps.refresh_failed')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('flow_detail.steps.refresh_retry')),
        );
        await tester.pump();
        verify(
          () => stepsBloc.add(const FlowStepsRefreshRequested()),
        ).called(1);
      },
    );

    testWidgets(
      'el scroll de la lista sobrevive el ciclo completo de una mutación '
      '(Loaded → Mutating → Refreshing → Loaded)',
      (tester) async {
        final many = <fdom.Step>[
          for (var i = 0; i < 15; i++) textStep(id: 's$i', order: i),
        ];
        final states = StreamController<FlowStepsState>();
        addTearDown(states.close);
        whenListen(
          stepsBloc,
          states.stream,
          initialState: FlowStepsLoaded(many),
        );

        await tester.pumpWidget(host());
        await tester.drag(
          find.byType(ReorderableListView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        final scrollable = find.descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        );
        final before = tester
            .state<ScrollableState>(scrollable.first)
            .position
            .pixels;
        expect(before, greaterThan(0));

        states.add(FlowStepsMutating(many));
        await tester.pump();
        states.add(FlowStepsRefreshing(many));
        await tester.pump();
        states.add(FlowStepsLoaded(many));
        await tester.pump();

        final after = tester
            .state<ScrollableState>(scrollable.first)
            .position
            .pixels;
        expect(after, before);
      },
    );

    testWidgets('el drag handle ofrece área táctil ≥48 y Semantics', (
      tester,
    ) async {
      when(() => stepsBloc.state).thenReturn(
        FlowStepsLoaded(<fdom.Step>[
          textStep(id: 's0'),
          labelStep(id: 's1', order: 1),
        ]),
      );

      await tester.pumpWidget(host());

      final handle = find.byKey(
        const Key('flow_detail.step_card.drag_handle.s1'),
      );
      expect(handle, findsOneWidget);
      final listener = find.ancestor(
        of: handle,
        matching: find.byType(ReorderableDragStartListener),
      );
      final size = tester.getSize(listener);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Mover paso',
        ),
        findsWidgets,
      );
    });
  });
}
