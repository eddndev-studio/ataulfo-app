import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/bots/presentation/pages/bots_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

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

  setUp(() {
    bloc = _MockBotsBloc();
    when(() => bloc.state).thenReturn(const BotsInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<BotsBloc>.value(
      value: bloc,
      // BotsListPage es content-only; el shell aporta Scaffold/AppBar.
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

  testWidgets('Loaded con N bots renderiza una AppCard por cada uno', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1, _b2], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Cobranza'), findsOneWidget);
    expect(find.byType(AppCard), findsNWidgets(2));
    // Los ListTile M3 ya no deben aparecer.
    expect(find.byType(ListTile), findsNothing);
    // Cada tile lleva su AppAvatar (sin Material CircleAvatar).
    expect(find.byType(AppAvatar), findsNWidgets(2));
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('bot pausado muestra AppPill neutral "Pausado"', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b2], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Pausado'), findsOneWidget);
    // El icono pause_circle legacy desaparece — el estado vive en el pill.
    expect(find.byIcon(Icons.pause_circle), findsNothing);
  });

  testWidgets('bot activo muestra AppPill primary "Activo"', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.widgetWithText(AppPill, 'Activo'), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsNothing);
    expect(find.byKey(const Key('bots.empty')), findsOneWidget);
  });

  testWidgets('Failed muestra mensaje genérico y botón Reintentar', (
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

  testWidgets('isRefreshing: true muestra la lista visible (no la oculta)', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: true));

    await tester.pumpWidget(host());

    // El contrato del shape `BotsLoaded(isRefreshing)` es justamente este:
    // la lista permanece visible mientras el spinner del RefreshIndicator
    // hace overlay (timing del overlay no es testeable de forma estable).
    expect(find.text('Soporte'), findsOneWidget);
  });

  testWidgets(
    'tap en un tile apila el detalle: navega Y deja back disponible',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

      // Espejo del test del listado de Templates: además de verificar la
      // navegación, el destino observa Navigator.canPop() para detectar
      // si la fuente apiló (push) o reemplazó la pila (go). go() saca
      // al usuario de la app con el back físico — el bug del smoke
      // device en V2314.
      final navigated = <String>[];
      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<BotsBloc>.value(
              value: bloc,
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

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Soporte'));
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
    // Mismo patrón que TemplatesListPage: tras pop de una sub-ruta
    // (e.g. /bots/new, /bots/:id), el shell vuelve al foreground y la
    // page dispara BotsRefreshRequested para alinear el bloc con el
    // backend sin pull-to-refresh manual.
    testWidgets(
      'al popear la ruta encima del listado, dispatcha BotsRefreshRequested',
      (tester) async {
        final observer = RouteObserver<PageRoute<dynamic>>();
        when(
          () => bloc.state,
        ).thenReturn(const BotsLoaded(items: <Bot>[_b1], isRefreshing: false));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            navigatorObservers: <NavigatorObserver>[observer],
            home: BlocProvider<BotsBloc>.value(
              value: bloc,
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
