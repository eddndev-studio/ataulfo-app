import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
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

const _ai = AIConfig(
  enabled: false,
  provider: AIProvider.gemini,
  model: 'gemini-3.1-pro-preview',
  temperature: 0.7,
  thinkingLevel: ThinkingLevel.low,
  systemPrompt: '',
  contextMessages: 20,
);

const _t1 = Template(
  id: 't1',
  orgId: 'o1',
  name: 'Soporte',
  version: 3,
  ai: _ai,
);
const _t2 = Template(
  id: 't2',
  orgId: 'o1',
  name: 'Ventas',
  version: 1,
  ai: _ai,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TemplatesLoadRequested());
  });

  late _MockTemplatesBloc bloc;

  setUp(() {
    bloc = _MockTemplatesBloc();
    when(() => bloc.state).thenReturn(const TemplatesInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<TemplatesBloc>.value(
      value: bloc,
      // TemplatesListPage es content-only; el shell aporta Scaffold/AppBar.
      // En aislamiento envolvemos en Scaffold para tener Material upstream.
      child: const Scaffold(body: TemplatesListPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const TemplatesLoading());

    await tester.pumpWidget(host());

    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets('Loaded con N templates renderiza una AppCard por cada uno', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[_t1, _t2], isRefreshing: false),
    );

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Ventas'), findsOneWidget);
    expect(find.byType(AppCard), findsNWidgets(2));
    // Los ListTile M3 ya no deben aparecer.
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    when(() => bloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );

    await tester.pumpWidget(host());

    expect(find.text('Soporte'), findsNothing);
    expect(find.byKey(const Key('templates.empty')), findsOneWidget);
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
      when(() => bloc.state).thenReturn(
        const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
      );

      // Capturamos la ubicación efectiva del router para verificar la
      // navegación. Adicionalmente, el destino expone un consumer que
      // observa Navigator.canPop(): si la fuente usó context.go() (que
      // REEMPLAZA la pila), canPop será false y el back físico del
      // sistema sacaría al usuario de la app — el bug reportado en el
      // smoke device. Con push (apila), canPop es true.
      final navigated = <String>[];
      final canPopAtDestination = <bool>[];
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<TemplatesBloc>.value(
              value: bloc,
              child: const Scaffold(body: TemplatesListPage()),
            ),
          ),
          GoRoute(
            path: '/templates/:id',
            builder: (_, state) {
              navigated.add('/templates/${state.pathParameters['id']}');
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

      expect(navigated, <String>['/templates/t1']);
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
    // Cuando el operador crea o edita una plantilla desde una sub-ruta
    // (push), al hacer pop el shell vuelve al foreground. Sin el
    // RouteObserver, el TemplatesBloc del shell sigue mostrando el
    // estado pre-mutación. La page se suscribe al observer y dispara
    // TemplatesRefreshRequested en didPopNext.
    testWidgets(
      'al popear la ruta encima del listado, dispatcha TemplatesRefreshRequested',
      (tester) async {
        final observer = RouteObserver<PageRoute<dynamic>>();
        when(() => bloc.state).thenReturn(
          const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            navigatorObservers: <NavigatorObserver>[observer],
            home: BlocProvider<TemplatesBloc>.value(
              value: bloc,
              child: Scaffold(body: TemplatesListPage(routeObserver: observer)),
            ),
          ),
        );
        // pump inicial: didChangeDependencies corre, subscribe ya está.
        // verifyNever para asegurar que el subscribe NO dispara refresh
        // por sí solo (sólo didPopNext debe).
        verifyNever(() => bloc.add(const TemplatesRefreshRequested()));

        // Push una ruta encima del listado (simula /templates/new o
        // /templates/:id/edit). El observer notifica didPushNext al
        // listado, pero ahí no hacemos nada.
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Sub-ruta')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pop la sub-ruta: el listado vuelve al foreground y el observer
        // notifica didPopNext → refresh.
        nav.pop();
        await tester.pumpAndSettle();

        verify(() => bloc.add(const TemplatesRefreshRequested())).called(1);
      },
    );

    testWidgets(
      'sin routeObserver (default null), no observa ni dispatcha — composición opcional',
      (tester) async {
        when(() => bloc.state).thenReturn(
          const TemplatesLoaded(items: <Template>[_t1], isRefreshing: false),
        );

        await tester.pumpWidget(host());
        // host() construye TemplatesListPage sin routeObserver.

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
