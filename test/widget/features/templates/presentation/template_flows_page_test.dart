import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as flows;
import 'package:ataulfo/features/flows/domain/failures/flows_failure.dart';
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/flows/presentation/bloc/flows_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_flows_page.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/triggers/presentation/bloc/triggers_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFlowsBloc extends MockBloc<FlowsEvent, FlowsState>
    implements FlowsBloc {}

class _MockTriggersBloc extends MockBloc<TriggersEvent, TriggersState>
    implements TriggersBloc {}

class _MockFlowsRepository extends Mock implements FlowsRepository {}

flows.Flow _flow({
  required String id,
  required String name,
  bool isActive = true,
  int cooldownMs = 0,
  int usageLimit = 0,
}) => flows.Flow(
  id: id,
  templateId: 't1',
  name: name,
  isActive: isActive,
  version: 1,
  cooldownMs: cooldownMs,
  usageLimit: usageLimit,
  excludesFlows: const <String>[],
);

Trigger _trigger({required String id, required String flowId}) => Trigger(
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
    registerFallbackValue(const FlowsLoadRequested());
    registerFallbackValue(const TriggersLoadRequested());
  });

  late _MockFlowsBloc flowsBloc;
  late _MockTriggersBloc triggersBloc;

  setUp(() {
    flowsBloc = _MockFlowsBloc();
    triggersBloc = _MockTriggersBloc();
    when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
    when(
      () => triggersBloc.state,
    ).thenReturn(const TriggersLoaded(<Trigger>[]));
  });

  // La página posee su Scaffold (AppBar + FAB), como las páginas del
  // entrenador: el host solo provee blocs.
  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<FlowsBloc>.value(value: flowsBloc),
        BlocProvider<TriggersBloc>.value(value: triggersBloc),
      ],
      child: const TemplateFlowsPage(templateId: 't1'),
    ),
  );

  testWidgets('Loading muestra spinner', (tester) async {
    when(() => flowsBloc.state).thenReturn(const FlowsLoading());

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flows.loading')), findsOneWidget);
  });

  testWidgets('Loaded([]) muestra empty state y oculta el buscador', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flows.empty')), findsOneWidget);
    // Sin flujos no hay nada que buscar; el campo solo agregaría ruido.
    expect(find.byKey(const Key('template_flows.search')), findsNothing);
  });

  testWidgets('Loaded con flujos: UNA card con las filas y divider entre '
      'ellas', (tester) async {
    when(() => flowsBloc.state).thenReturn(
      FlowsLoaded(<flows.Flow>[
        _flow(id: 'f1', name: 'Bienvenida'),
        _flow(id: 'f2', name: 'Despedida', isActive: false),
      ]),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flows.row.f1')), findsOneWidget);
    expect(find.byKey(const Key('flows.row.f2')), findsOneWidget);
    expect(find.text('Bienvenida'), findsOneWidget);
    expect(find.text('Despedida'), findsOneWidget);

    // Ambas filas viven dentro de la MISMA card, separadas por un divider
    // hairline — no una card suelta por flujo.
    final cardWithRow = find.ancestor(
      of: find.byKey(const Key('flows.row.f1')),
      matching: find.byType(AppCard),
    );
    expect(cardWithRow, findsOneWidget);
    expect(
      find.descendant(
        of: cardWithRow,
        matching: find.byKey(const Key('flows.row.f2')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardWithRow, matching: find.byType(Divider)),
      findsOneWidget,
    );
  });

  testWidgets('estado con dos voces: el flujo activo calla y el pausado '
      'habla como pill', (tester) async {
    when(() => flowsBloc.state).thenReturn(
      FlowsLoaded(<flows.Flow>[
        _flow(id: 'f1', name: 'Bienvenida'),
        _flow(id: 'f2', name: 'Despedida', isActive: false),
      ]),
    );

    await tester.pumpWidget(host());

    // Activo es el default: no pinta pill ni texto — repetirlo por fila
    // sana sería ruido.
    expect(find.byKey(const Key('flows.row.f1.status_pill')), findsNothing);
    expect(find.text('Activo'), findsNothing);

    // Pausado es el estado excepcional: sí merece la cápsula.
    final pausedPill = find.byKey(const Key('flows.row.f2.status_pill'));
    expect(pausedPill, findsOneWidget);
    expect(tester.widget(pausedPill), isA<AppPill>());
    expect(
      find.descendant(of: pausedPill, matching: find.text('Pausado')),
      findsOneWidget,
    );
  });

  testWidgets('el scroll despeja el FAB de crear al fondo', (tester) async {
    when(() => flowsBloc.state).thenReturn(
      FlowsLoaded(<flows.Flow>[_flow(id: 'f1', name: 'Bienvenida')]),
    );

    await tester.pumpWidget(host());

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('template_flows.content')),
    );
    final resolved = scroll.padding!.resolve(TextDirection.ltr);
    expect(resolved.bottom, greaterThanOrEqualTo(AppTokens.fabClearance));
  });

  group('tarjetas ricas', () {
    testWidgets(
      'la tarjeta resume disparadores, enfriamiento y límite de uso',
      (tester) async {
        when(() => flowsBloc.state).thenReturn(
          FlowsLoaded(<flows.Flow>[
            _flow(
              id: 'f1',
              name: 'Bienvenida',
              cooldownMs: 5 * 60 * 60 * 1000, // 5 h
              usageLimit: 10,
            ),
          ]),
        );
        when(() => triggersBloc.state).thenReturn(
          TriggersLoaded(<Trigger>[
            _trigger(id: 'g1', flowId: 'f1'),
            _trigger(id: 'g2', flowId: 'f1'),
            _trigger(id: 'g3', flowId: 'f1'),
          ]),
        );

        await tester.pumpWidget(host());

        final card = find.byKey(const Key('flows.row.f1'));
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('3 disparadores'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('5 h')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('límite 10')),
          findsOneWidget,
        );
      },
    );

    testWidgets('flujo sin gates ni triggers: caption "Sin disparadores"', (
      tester,
    ) async {
      when(() => flowsBloc.state).thenReturn(
        FlowsLoaded(<flows.Flow>[_flow(id: 'f1', name: 'Bienvenida')]),
      );

      await tester.pumpWidget(host());

      expect(
        find.descendant(
          of: find.byKey(const Key('flows.row.f1')),
          matching: find.textContaining('Sin disparadores'),
        ),
        findsOneWidget,
      );
    });
  });

  group('buscador', () {
    setUp(() {
      when(() => flowsBloc.state).thenReturn(
        FlowsLoaded(<flows.Flow>[
          _flow(id: 'f1', name: 'Bienvenida'),
          _flow(id: 'f2', name: 'Despedida', isActive: false),
          _flow(id: 'f3', name: 'Bienvenida VIP'),
        ]),
      );
    });

    testWidgets('filtra por nombre (case-insensitive)', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byType(AppSearchField), findsOneWidget);
      final search = tester.widget<AppSearchField>(
        find.byKey(const Key('template_flows.search')),
      );
      expect(search.hint, 'Buscar flujos por nombre…');
      await tester.enterText(
        find.byKey(const Key('template_flows.search')),
        'bien',
      );
      await tester.pump();

      expect(find.byKey(const Key('flows.row.f1')), findsOneWidget);
      expect(find.byKey(const Key('flows.row.f3')), findsOneWidget);
      expect(find.byKey(const Key('flows.row.f2')), findsNothing);
    });

    testWidgets('sin coincidencias muestra mensaje de no-resultados', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('template_flows.search')),
        'zzz',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('template_flows.no_results')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('flows.row.f1')), findsNothing);
    });

    testWidgets('limpiar el query restaura la lista completa', (tester) async {
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('template_flows.search')),
        'bien',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('template_flows.search')),
        '',
      );
      await tester.pump();

      expect(find.byKey(const Key('flows.row.f1')), findsOneWidget);
      expect(find.byKey(const Key('flows.row.f2')), findsOneWidget);
      expect(find.byKey(const Key('flows.row.f3')), findsOneWidget);
    });
  });

  testWidgets('FlowsFailed muestra error con Reintentar que dispatcha load', (
    tester,
  ) async {
    when(
      () => flowsBloc.state,
    ).thenReturn(const FlowsFailed(FlowsServerFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flows.failed')), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => flowsBloc.add(const FlowsLoadRequested())).called(1);
  });

  testWidgets('la copy del fallo sale del textTheme (bodyMedium + danger)', (
    tester,
  ) async {
    when(
      () => flowsBloc.state,
    ).thenReturn(const FlowsFailed(FlowsServerFailure()));

    await tester.pumpWidget(host());

    final context = tester.element(find.byKey(const Key('flows.failed')));
    final textTheme = Theme.of(context).textTheme;
    final copy = tester.widget<Text>(
      find.text('No pudimos cargar los flujos.'),
    );
    expect(copy.style, textTheme.bodyMedium?.copyWith(color: AppTokens.danger));
  });

  testWidgets('la fila ya no ofrece basurero: el flujo se elimina desde su '
      'editor', (tester) async {
    when(() => flowsBloc.state).thenReturn(
      FlowsLoaded(<flows.Flow>[_flow(id: 'f1', name: 'Bienvenida')]),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('flows.row.f1.delete')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('la página posee AppBar "Flujos" y FAB [+]; muere el botón '
      'inline de texto', (tester) async {
    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppBar, 'Flujos'), findsOneWidget);
    expect(find.byKey(const Key('template_flows.fab')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('template_flows.fab')),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('flows.add_button')), findsNothing);
    expect(find.text('Nuevo flujo'), findsNothing);
  });

  group('navegación', () {
    testWidgets('tap del FAB abre el form-sheet de nuevo flujo', (
      tester,
    ) async {
      when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
      final repo = _MockFlowsRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignTheme.dark(),
          home: RepositoryProvider<FlowsRepository>.value(
            value: repo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowsBloc>.value(value: flowsBloc),
                BlocProvider<TriggersBloc>.value(value: triggersBloc),
              ],
              child: const TemplateFlowsPage(templateId: 't1'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('template_flows.fab')));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo flujo'), findsOneWidget);
      expect(find.byKey(const Key('flow_create.field.name')), findsOneWidget);
    });

    testWidgets('crear desde el sheet navega al editor del flujo nuevo', (
      tester,
    ) async {
      when(() => flowsBloc.state).thenReturn(const FlowsLoaded(<flows.Flow>[]));
      final repo = _MockFlowsRepository();
      when(
        () => repo.createFlow(templateId: 't1', name: 'Bienvenida'),
      ).thenAnswer((_) async => _flow(id: 'f-new', name: 'Bienvenida'));

      String? destinationUri;
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => RepositoryProvider<FlowsRepository>.value(
              value: repo,
              child: MultiBlocProvider(
                providers: <BlocProvider<dynamic>>[
                  BlocProvider<FlowsBloc>.value(value: flowsBloc),
                  BlocProvider<TriggersBloc>.value(value: triggersBloc),
                ],
                child: const TemplateFlowsPage(templateId: 't1'),
              ),
            ),
          ),
          GoRoute(
            path: '/flows/:id',
            builder: (_, st) {
              destinationUri = st.uri.toString();
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('template_flows.fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('flow_create.field.name')),
        'Bienvenida',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('flow_create.submit')));
      await tester.pumpAndSettle();

      expect(destinationUri, '/flows/f-new');
      expect(
        find.text('Nuevo flujo'),
        findsNothing,
        reason: 'el sheet cerró antes de navegar al editor',
      );
    });

    testWidgets('al volver del editor la lista se refresca', (tester) async {
      when(() => flowsBloc.state).thenReturn(
        FlowsLoaded(<flows.Flow>[_flow(id: 'f1', name: 'Bienvenida')]),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowsBloc>.value(value: flowsBloc),
                BlocProvider<TriggersBloc>.value(value: triggersBloc),
              ],
              child: const TemplateFlowsPage(templateId: 't1'),
            ),
          ),
          GoRoute(
            path: '/flows/:id',
            builder: (_, _) => Scaffold(
              appBar: AppBar(),
              body: const Text('editor del flujo'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flows.row.f1')));
      await tester.pumpAndSettle();
      verifyNever(() => flowsBloc.add(const FlowsLoadRequested()));

      await tester.pageBack();
      await tester.pumpAndSettle();

      verify(() => flowsBloc.add(const FlowsLoadRequested())).called(1);
      // El count de disparadores por fila tambien puede haber cambiado.
      verify(() => triggersBloc.add(const TriggersLoadRequested())).called(1);
    });

    testWidgets('tap del row apila /flows/:id', (tester) async {
      when(() => flowsBloc.state).thenReturn(
        FlowsLoaded(<flows.Flow>[_flow(id: 'f1', name: 'Bienvenida')]),
      );
      String? destinationUri;
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<FlowsBloc>.value(value: flowsBloc),
                BlocProvider<TriggersBloc>.value(value: triggersBloc),
              ],
              child: const TemplateFlowsPage(templateId: 't1'),
            ),
          ),
          GoRoute(
            path: '/flows/:id',
            builder: (_, st) {
              destinationUri = st.uri.toString();
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('flows.row.f1')));
      await tester.pumpAndSettle();

      expect(destinationUri, '/flows/f1');
    });
  });
}
