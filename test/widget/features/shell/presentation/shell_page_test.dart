import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:agentic/features/bots/presentation/pages/bots_list_page.dart';
import 'package:agentic/features/settings/presentation/pages/settings_page.dart';
import 'package:agentic/features/shell/presentation/pages/shell_page.dart';
import 'package:agentic/features/templates/domain/entities/template.dart';
import 'package:agentic/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:agentic/features/templates/presentation/pages/templates_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsBloc botsBloc;
  late _MockTemplatesBloc templatesBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsBloc = _MockBotsBloc();
    templatesBloc = _MockTemplatesBloc();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    // Loaded([]) en vez de Loading: el spinner del CircularProgressIndicator
    // tiene animación infinita y pumpAndSettle nunca termina. Loaded es
    // estado terminal sin animaciones; cubre el árbol que necesitamos
    // navegar.
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
    when(() => templatesBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );
  });

  Widget host() => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BotsBloc>.value(value: botsBloc),
      BlocProvider<TemplatesBloc>.value(value: templatesBloc),
    ],
    child: const MaterialApp(home: ShellPage()),
  );

  // El breakpoint M3 compact→medium está en 600dp. Convertimos a píxeles
  // físicos vía devicePixelRatio para que LayoutBuilder lo resuelva en dp.
  void useViewport(WidgetTester tester, {required double widthDp}) {
    const dpr = 3.0;
    tester.view.physicalSize = Size(widthDp * dpr, 800 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('layout adaptable (breakpoint 600dp M3)', () {
    testWidgets('phone (<600dp) usa BottomNavigationBar, no NavigationRail', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('tablet (≥600dp) usa NavigationRail, no BottomNavigationBar', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });

  group('navegación entre tabs', () {
    testWidgets('arranca en la tab Bots (BotsListPage visible)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(find.byType(BotsListPage), findsOneWidget);
      // Otras pages existen en el IndexedStack pero quedan offstage —
      // su contenido no debe ser visible al usuario.
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.byKey(const Key('templates.empty')), findsNothing);
    });

    testWidgets('tab Plantillas presente en BottomNavigationBar (phone)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      // Texto "Bots" aparece también en el AppBar (título dinámico de la
      // tab activa). Filtramos por descendiente del BottomNavigationBar
      // para verificar la presencia de cada label dentro del nav.
      Finder inNav(String label) => find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(label),
      );

      expect(inNav('Bots'), findsOneWidget);
      expect(inNav('Plantillas'), findsOneWidget);
      expect(inNav('Ajustes'), findsOneWidget);
    });

    testWidgets('tap Plantillas (phone) muestra TemplatesListPage', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(find.text('Plantillas'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplatesListPage), findsOneWidget);
      // El empty state de Templates (TemplatesLoaded([]) del stub) confirma
      // que el árbol del bloc llegó al widget.
      expect(find.byKey(const Key('templates.empty')), findsOneWidget);
    });

    testWidgets('tap Plantillas (tablet) muestra TemplatesListPage', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());
      await tester.tap(find.text('Plantillas'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplatesListPage), findsOneWidget);
    });

    testWidgets('tap Settings (phone) muestra SettingsPage', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('tap Settings (tablet) muestra SettingsPage', (tester) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());
      // NavigationRail muestra ícono + label; tap por label.
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('cambiar tab preserva el BotsBloc del shell (mismo instance)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      // Capturamos el bloc visto desde Bots tab.
      final blocBefore = tester
          .element(find.byType(BotsListPage))
          .read<BotsBloc>();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bots'));
      await tester.pumpAndSettle();
      final blocAfter = tester
          .element(find.byType(BotsListPage))
          .read<BotsBloc>();

      // El cambio de tab NO debe reconstruir el bloc — el provider está
      // en el route builder, no dentro de cada tab.
      expect(identical(blocBefore, blocAfter), isTrue);
    });

    testWidgets('tab Bots (phone) expone FAB de selector de plantilla', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('shell.fab.bot_template_picker')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.fab.template_create')), findsNothing);
    });

    testWidgets('tab Bots (tablet) expone FAB de selector de plantilla', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('shell.fab.bot_template_picker')),
        findsOneWidget,
      );
    });

    testWidgets('tab Plantillas (phone) expone FAB de crear plantilla', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Plantillas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shell.fab.template_create')),
        findsOneWidget,
      );
    });

    testWidgets('tab Plantillas (tablet) expone FAB de crear plantilla', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Plantillas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shell.fab.template_create')),
        findsOneWidget,
      );
    });

    testWidgets('tab Ajustes no expone FAB', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell.fab.template_create')), findsNothing);
      expect(
        find.byKey(const Key('shell.fab.bot_template_picker')),
        findsNothing,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('tap FAB en tab Bots apila /bots/new sobre el shell '
        '(back desde el picker vuelve al shell, NO sale de la app)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      // Mismo contrato que el FAB de plantillas: push (no go) para que
      // canPop()==true en el destino. Si el FAB usara go() el back físico
      // sacaría al operador de la app en lugar de cancelar la selección.
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
                BlocProvider<BotsBloc>.value(value: botsBloc),
                BlocProvider<TemplatesBloc>.value(value: templatesBloc),
              ],
              child: const ShellPage(),
            ),
          ),
          GoRoute(
            path: '/bots/new',
            builder: (_, _) {
              navigated.add('/bots/new');
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
      await tester.tap(find.byKey(const Key('shell.fab.bot_template_picker')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/bots/new']);
      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'el selector debe quedar apilado sobre el shell para que el '
            'back físico cancele la elección y vuelva al listado',
      );
    });

    testWidgets('tap FAB en tab Plantillas apila /templates/new sobre el shell '
        '(back sin crear vuelve al shell, NO sale de la app)', (tester) async {
      useViewport(tester, widthDp: 420);

      // Reproducción del bug del smoke device V2314: con context.go()
      // el shell se aplasta y back sin crear sale de la app. Con push()
      // el shell queda debajo (canPop = true en el destino).
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
                BlocProvider<BotsBloc>.value(value: botsBloc),
                BlocProvider<TemplatesBloc>.value(value: templatesBloc),
              ],
              child: const ShellPage(),
            ),
          ),
          GoRoute(
            path: '/templates/new',
            builder: (_, _) {
              navigated.add('/templates/new');
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
      await tester.tap(find.text('Plantillas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shell.fab.template_create')));
      await tester.pumpAndSettle();

      expect(navigated, <String>['/templates/new']);
      expect(
        canPopAtDestination,
        <bool>[true],
        reason:
            'el formulario debe quedar apilado sobre el shell para que '
            'el back físico cancele la creación y vuelva al listado',
      );
    });

    testWidgets(
      'cambiar tab preserva el TemplatesBloc del shell (mismo instance)',
      (tester) async {
        useViewport(tester, widthDp: 420);

        await tester.pumpWidget(host());
        await tester.tap(find.text('Plantillas'));
        await tester.pumpAndSettle();
        final blocBefore = tester
            .element(find.byType(TemplatesListPage))
            .read<TemplatesBloc>();
        await tester.tap(find.text('Bots'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plantillas'));
        await tester.pumpAndSettle();
        final blocAfter = tester
            .element(find.byType(TemplatesListPage))
            .read<TemplatesBloc>();

        expect(identical(blocBefore, blocAfter), isTrue);
      },
    );
  });
}
