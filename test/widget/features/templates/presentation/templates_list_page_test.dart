import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_dot_label.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_page_header.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/failures/templates_failure.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/templates_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

const _aiOn = AIConfig(
  enabled: true,
  provider: AIProvider.openai,
  model: 'gpt-5',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.high,
  systemPrompt: '',
  contextMessages: 10,
);
const _aiOff = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

// t1: IA encendida + counts no triviales (3/12/4).
const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 3,
  ai: _aiOn,
  counts: TemplateCounts(bots: 3, flows: 12, variables: 4),
);
// t2: IA apagada + counts en cero (deben mostrarse, no omitirse).
const _t2 = Template(
  id: 't2',
  orgId: 'o1',
  name: 'Ventas',
  version: 1,
  ai: _aiOff,
  counts: TemplateCounts(bots: 0, flows: 1, variables: 0),
);
// t3: sin counts (null) — respuesta sin enriquecer; la fila se omite.
const _t3 = Template(
  id: 't3',
  orgId: 'o1',
  name: 'Heredada',
  version: 1,
  ai: _aiOff,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplatesLoadRequested());
  });

  late _MockTemplatesBloc bloc;
  late _MockAuthBloc authBloc;

  setUp(() {
    bloc = _MockTemplatesBloc();
    when(() => bloc.state).thenReturn(const TemplatesInitial());
    authBloc = _MockAuthBloc();
    // La sesión aporta la identidad al acceso de perfil cuando el shell lo usa.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<TemplatesBloc>.value(value: bloc),
      ],
      child: const Scaffold(body: TemplatesListPage()),
    ),
  );

  void loaded(List<Template> items) {
    when(
      () => bloc.state,
    ).thenReturn(TemplatesLoaded(items: items, isRefreshing: false));
  }

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const TemplatesLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
    // El spinner de página es el primitivo canónico del kit.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets(
    'Loaded monta el header neutro compacto con título "Asistentes"',
    (tester) async {
      loaded(const <Template>[_t1]);
      await tester.pumpWidget(host());

      expect(find.byType(AppPageHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppPageHeader),
          matching: find.text('Asistentes'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Loaded renderiza un tile por template (sin ListTile M3)', (
    tester,
  ) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('templates.tile.t1')), findsOneWidget);
    expect(find.byKey(const Key('templates.tile.t2')), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Ventas'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
    'tile con counts muestra canales/flujos/variables (pluralizado)',
    (tester) async {
      loaded(const <Template>[_t1]);
      await tester.pumpWidget(host());

      expect(find.text('3 canales'), findsOneWidget);
      expect(find.text('12 flujos'), findsOneWidget);
      expect(find.text('4 variables'), findsOneWidget);
    },
  );

  testWidgets('counts en cero se muestran; singular sin "s" (1 flujo)', (
    tester,
  ) async {
    loaded(const <Template>[_t2]);
    await tester.pumpWidget(host());

    expect(find.text('0 canales'), findsOneWidget);
    expect(find.text('1 flujo'), findsOneWidget);
    expect(find.text('0 variables'), findsOneWidget);
  });

  testWidgets('template sin counts (null) omite la fila de métricas', (
    tester,
  ) async {
    loaded(const <Template>[_t3]);
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('templates.tile.t3')), findsOneWidget);
    expect(find.byKey(const Key('templates.metrics.t3')), findsNothing);
  });

  testWidgets('badge IA: encendida muestra proveedor; apagada "Sin IA"', (
    tester,
  ) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    // "Sin IA" también es un chip de filtro: acotamos al tile correspondiente.
    expect(
      find.descendant(
        of: find.byKey(const Key('templates.tile.t1')),
        matching: find.text('IA · OpenAI'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('templates.tile.t2')),
        matching: find.text('Sin IA'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('las plantillas viven en UNA card con dividers', (tester) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    final cardsWithTile = find.ancestor(
      of: find.byKey(const Key('templates.tile.t1')),
      matching: find.byType(AppCard),
    );
    expect(cardsWithTile, findsOneWidget);
    expect(
      find.descendant(
        of: cardsWithTile,
        matching: find.byKey(const Key('templates.tile.t2')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardsWithTile, matching: find.byType(Divider)),
      findsOneWidget,
    );
  });

  testWidgets('IA encendida es un indicador quieto con dot success, sin pill', (
    tester,
  ) async {
    loaded(const <Template>[_t1]);
    await tester.pumpWidget(host());

    final tile = find.byKey(const Key('templates.tile.t1'));
    expect(
      find.descendant(
        of: tile,
        matching: find.widgetWithText(AppDotLabel, 'IA · OpenAI'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byType(AppPill)),
      findsNothing,
    );

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('app_dot_label.dot')),
    );
    expect((dot.decoration as BoxDecoration).color, AppTokens.success);
  });

  testWidgets('el scroll despeja el FAB del shell al fondo', (tester) async {
    loaded(const <Template>[_t1]);
    await tester.pumpWidget(host());

    final padding = tester.widget<Padding>(
      find.byKey(const Key('templates.content_padding')),
    );
    final resolved = padding.padding.resolve(TextDirection.ltr);
    expect(resolved.bottom, greaterThanOrEqualTo(AppTokens.fabClearance));
  });

  testWidgets('búsqueda filtra por nombre', (tester) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    expect(find.byType(AppSearchField), findsOneWidget);
    final search = tester.widget<AppSearchField>(
      find.byKey(const Key('templates.search')),
    );
    expect(search.hint, 'Buscar asistentes por nombre…');
    await tester.enterText(find.byKey(const Key('templates.search')), 'Vent');
    await tester.pump();

    expect(find.byKey(const Key('templates.tile.t2')), findsOneWidget);
    expect(find.byKey(const Key('templates.tile.t1')), findsNothing);
  });

  testWidgets('filtro "Con IA" deja solo las que tienen IA encendida', (
    tester,
  ) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('templates.filter.with_ai')));
    await tester.pump();

    expect(find.byKey(const Key('templates.tile.t1')), findsOneWidget); // IA on
    expect(find.byKey(const Key('templates.tile.t2')), findsNothing); // IA off
  });

  testWidgets('filtro "Sin IA" deja solo las que tienen IA apagada', (
    tester,
  ) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('templates.filter.without_ai')));
    await tester.pump();

    expect(find.byKey(const Key('templates.tile.t2')), findsOneWidget); // off
    expect(find.byKey(const Key('templates.tile.t1')), findsNothing); // on
  });

  testWidgets('búsqueda sin coincidencias muestra no-results', (tester) async {
    loaded(const <Template>[_t1, _t2]);
    await tester.pumpWidget(host());

    await tester.enterText(find.byType(TextField), 'zzz-no-existe');
    await tester.pump();

    expect(find.byKey(const Key('templates.no_results')), findsOneWidget);
    expect(find.byKey(const Key('templates.tile.t1')), findsNothing);
    expect(find.byKey(const Key('templates.tile.t2')), findsNothing);
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    loaded(const <Template>[]);
    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsNothing);
    expect(find.byKey(const Key('templates.empty')), findsOneWidget);
    // El vacío rico es el primitivo canónico del kit (misma anatomía).
    expect(find.byType(AppEmptyState), findsOneWidget);
  });

  testWidgets('Failed muestra mensaje genérico y botón Reintentar', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplatesFailed(TemplatesNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('templates.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    // La card de error es el primitivo canónico del kit (misma anatomía).
    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('tap Reintentar dispara TemplatesLoadRequested', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const TemplatesFailed(TemplatesServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const TemplatesLoadRequested())).called(1);
  });

  testWidgets('isRefreshing: true muestra la lista visible (no la oculta)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[_t1], isRefreshing: true),
    );

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
  });

  testWidgets(
    'tap en un tile apila el detalle: navega Y deja back disponible',
    (tester) async {
      loaded(const <Template>[_t1]);

      final navigated = <String>[];
      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<TemplatesBloc>.value(value: bloc),
              ],
              child: const Scaffold(body: TemplatesListPage()),
            ),
          ),
          GoRoute(
            path: '/assistants/:id',
            builder: (_, state) {
              navigated.add('/assistants/${state.pathParameters['id']}');
              return Scaffold(
                body: Builder(
                  builder: (ctx) {
                    canPopAtDestination.add(Navigator.of(ctx).canPop());
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byKey(const Key('templates.tile.t1')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/assistants/t1']);
      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'el detalle debe quedar apilado sobre el listado para que el back '
            'físico (o el AppBar back arrow) vuelva al shell',
      );
    },
  );

  group('auto-refresh al volver al listado (RouteAware)', () {
    testWidgets(
      'al popear la ruta encima del listado, dispatcha TemplatesRefreshRequested',
      (tester) async {
        final observer = RouteObserver<PageRoute<dynamic>>();
        loaded(const <Template>[_t1]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            navigatorObservers: <NavigatorObserver>[observer],
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<TemplatesBloc>.value(value: bloc),
              ],
              child: Scaffold(body: TemplatesListPage(routeObserver: observer)),
            ),
          ),
        );
        verifyNever(() => bloc.add(const TemplatesRefreshRequested()));

        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Sub-ruta')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        nav.pop();
        await tester.pumpAndSettle();

        verify(() => bloc.add(const TemplatesRefreshRequested())).called(1);
      },
    );

    testWidgets(
      'sin routeObserver (default null), no observa ni dispatcha — composición opcional',
      (tester) async {
        loaded(const <Template>[_t1]);

        await tester.pumpWidget(host());

        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Sub-ruta')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        nav.pop();
        await tester.pumpAndSettle();

        verifyNever(() => bloc.add(const TemplatesRefreshRequested()));
      },
    );
  });
}
