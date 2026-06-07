import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_entity_icon.dart';
import 'package:ataulfo/core/design/widgets/app_header_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bots_list_page.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

class _MockBotsRepository extends Mock implements BotsRepository {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

const _b1 = Bot(
  id: 'b1',
  orgId: 'o1',
  templateId: 't1',
  name: 'Soporte',
  channel: BotChannel.waUnofficial,
  identifier: '52155...',
  version: 3,
  paused: false,
  aiDisabled: false,
);
const _b2 = Bot(
  id: 'b2',
  orgId: 'o1',
  templateId: 't1',
  name: 'Cobranza',
  channel: BotChannel.waba,
  identifier: null,
  version: 1,
  paused: true,
  aiDisabled: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const BotsLoadRequested());
  });

  late _MockBotsBloc bloc;
  late _MockAuthBloc authBloc;

  setUp(() {
    bloc = _MockBotsBloc();
    when(() => bloc.state).thenReturn(const BotsInitial());
    authBloc = _MockAuthBloc();
    // El header rico saluda con el nombre derivado del email de la sesión.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
  });

  // Viewport alto: el contenido (header + CTA + buscador + filtros + lista)
  // supera el alto default de flutter_test (600), y la lista se construye
  // eager para que los `find` lleguen a tiles fuera del fold.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<BotsBloc>.value(value: bloc),
      ],
      // BotsListPage es content-only; el shell aporta Scaffold/AppBar/FAB.
      // En aislamiento envolvemos en Scaffold para tener Material upstream.
      child: const Scaffold(body: BotsListPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const BotsLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded monta el header rico full-bleed con título "Agentes"', (
    tester,
  ) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

    await tester.pumpWidget(host());

    // El AppHeaderCard reemplaza al AppBar del shell para esta sección.
    expect(find.byType(AppHeaderCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppHeaderCard),
        matching: find.text('Agentes'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Loaded con bots: una card-tile por bot con AppEntityIcon (NO '
      'AppAvatar)', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bots.tile.b1')), findsOneWidget);
    expect(find.byKey(const Key('bots.tile.b2')), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Cobranza'), findsOneWidget);
    // Un bot NO es un perfil: glifo de entidad, nunca avatar de perfil.
    expect(find.byType(AppAvatar), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(AppEntityIcon), findsWidgets);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('el buscador filtra por nombre', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    await tester.enterText(find.byType(TextField), 'cob');
    await tester.pump();

    expect(find.byKey(const Key('bots.tile.b2')), findsOneWidget);
    expect(find.byKey(const Key('bots.tile.b1')), findsNothing);
  });

  testWidgets('filtro "Pausados" muestra solo bots pausados', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('bots.filter.paused')));
    await tester.pump();

    expect(find.byKey(const Key('bots.tile.b2')), findsOneWidget); // Cobranza
    expect(find.byKey(const Key('bots.tile.b1')), findsNothing); // Soporte
  });

  testWidgets('filtro "Activos" muestra solo bots activos', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    await tester.tap(find.byKey(const Key('bots.filter.active')));
    await tester.pump();

    expect(find.byKey(const Key('bots.tile.b1')), findsOneWidget); // Soporte
    expect(find.byKey(const Key('bots.tile.b2')), findsNothing); // Cobranza
  });

  testWidgets('búsqueda sin coincidencias muestra "sin resultados"', (
    tester,
  ) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    await tester.enterText(find.byType(TextField), 'zzz-no-existe');
    await tester.pump();

    expect(find.byKey(const Key('bots.no_results')), findsOneWidget);
    expect(find.byKey(const Key('bots.tile.b1')), findsNothing);
    expect(find.byKey(const Key('bots.tile.b2')), findsNothing);
  });

  testWidgets('bot pausado muestra AppPill "Pausado"', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b2], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle), findsNothing);
  });

  testWidgets('bot activo muestra AppPill "Activo"', (tester) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra empty state glass con CTA "Crear bot"', (
    tester,
  ) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsNothing);
    expect(find.byKey(const Key('bots.empty')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Crear bot'), findsOneWidget);
  });

  testWidgets('empty: CTA "Crear bot" abre la hoja de creación', (
    tester,
  ) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
    final tplBloc = _MockTemplatesBloc();
    when(() => tplBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );
    final botsRepo = _MockBotsRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: RepositoryProvider<BotsRepository>.value(
          value: botsRepo,
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<BotsBloc>.value(value: bloc),
              BlocProvider<TemplatesBloc>.value(value: tplBloc),
            ],
            child: const Scaffold(body: BotsListPage()),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(AppButton, 'Crear bot'));
    await tester.pumpAndSettle();

    // La hoja (wizard de bot) arranca en el paso de selección de plantilla.
    expect(find.text('Elegir plantilla'), findsOneWidget);
  });

  testWidgets('Failed muestra card de error y botón Reintentar', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const BotsFailed(BotsNetworkFailure()));

    await tester.pumpWidget(host());

    expect(find.byKey(const Key('bots.error')), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('tap Reintentar dispara BotsLoadRequested', (tester) async {
    when(() => bloc.state).thenReturn(const BotsFailed(BotsServerFailure()));

    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();

    verify(() => bloc.add(const BotsLoadRequested())).called(1);
  });

  testWidgets('isRefreshing: true mantiene la lista visible (no la oculta)', (
    tester,
  ) async {
    tall(tester);
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: true));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
  });

  testWidgets(
    'tap en un tile apila el detalle: navega Y deja back disponible',
    (tester) async {
      tall(tester);
      when(
        () => bloc.state,
      ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

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
                BlocProvider<BotsBloc>.value(value: bloc),
              ],
              child: const Scaffold(body: BotsListPage()),
            ),
          ),
          GoRoute(
            path: '/bots/:id',
            builder: (_, state) {
              navigated.add('/bots/${state.pathParameters['id']}');
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

      await tester.pumpWidget(
        MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
      );
      await tester.tap(find.byKey(const Key('bots.tile.b1')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/bots/b1']);
      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'el detalle debe quedar apilado sobre el listado para que el '
            'back físico (o el AppBar back arrow) vuelva al shell',
      );
    },
  );

  group('auto-refresh al volver al listado (RouteAware)', () {
    testWidgets(
      'al popear la ruta encima del listado, dispatcha BotsRefreshRequested',
      (tester) async {
        tall(tester);
        final observer = RouteObserver<PageRoute<dynamic>>();
        when(
          () => bloc.state,
        ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            navigatorObservers: <NavigatorObserver>[observer],
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<BotsBloc>.value(value: bloc),
              ],
              child: Scaffold(body: BotsListPage(routeObserver: observer)),
            ),
          ),
        );
        verifyNever(() => bloc.add(const BotsRefreshRequested()));

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

        verify(() => bloc.add(const BotsRefreshRequested())).called(1);
      },
    );

    testWidgets(
      'sin routeObserver (default null), no observa ni dispatcha — composición opcional',
      (tester) async {
        tall(tester);
        when(
          () => bloc.state,
        ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

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

        verifyNever(() => bloc.add(const BotsRefreshRequested()));
      },
    );
  });
}
