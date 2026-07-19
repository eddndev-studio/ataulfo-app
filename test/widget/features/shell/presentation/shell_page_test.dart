import 'package:ataulfo/core/design/widgets/app_icon_pop.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/labels/presentation/pages/labels_admin_page.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:ataulfo/features/settings/presentation/pages/settings_page.dart';
import 'package:ataulfo/features/shell/presentation/pages/shell_page.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/templates_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

class _MockLabelsAdminBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

class _MockPaBloc extends MockBloc<PaChatEvent, PaChatState>
    implements PlatformAgentChatBloc {}

class _MockTemplatesRepository extends Mock implements TemplatesRepository {}

// emailVerified: true mantiene el aviso de verificación ausente en estas
// pruebas de layout/navegación — su presencia/ausencia se cubre en
// email_verification_banner_test y shell_banner_test.
const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsBloc botsBloc;
  late _MockTemplatesBloc templatesBloc;
  late _MockLabelsAdminBloc labelsBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsBloc = _MockBotsBloc();
    templatesBloc = _MockTemplatesBloc();
    labelsBloc = _MockLabelsAdminBloc();
    when(() => labelsBloc.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false),
    );
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
      BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
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

  group('íconos de tabs (variante filled + pop en la selección)', () {
    Finder inNav(Finder matching) => find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: matching,
    );

    testWidgets('la tab activa pinta filled con AppIconPop; las inactivas, '
        'outline plano', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      // Asistentes activa: variante filled envuelta en el pop del kit.
      expect(inNav(find.byIcon(Icons.support_agent)), findsOneWidget);
      expect(inNav(find.byType(AppIconPop)), findsOneWidget);
      expect(inNav(find.byIcon(Icons.support_agent_outlined)), findsNothing);
      // Ataúlfo está inactivo y no lleva el wrapper animado.
      expect(inNav(find.byIcon(Icons.auto_awesome)), findsOneWidget);
    });

    testWidgets('cambiar de tab mueve el filled+pop a la nueva selección', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Etiquetas'));
      await tester.pumpAndSettle();

      expect(inNav(find.byIcon(Icons.support_agent_outlined)), findsOneWidget);
      expect(inNav(find.byIcon(Icons.support_agent)), findsNothing);
      expect(inNav(find.byIcon(Icons.label)), findsOneWidget);
      expect(inNav(find.byType(AppIconPop)), findsOneWidget);
    });

    testWidgets('el rail (≥600dp) también pinta filled+pop en la selección', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final inRail = find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byType(AppIconPop),
      );
      expect(inRail, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.support_agent),
        ),
        findsOneWidget,
      );
    });
  });

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
    testWidgets('arranca en la tab Asistentes (catálogo visible)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(find.byType(TemplatesListPage), findsOneWidget);
      // Otras pages existen en el IndexedStack pero quedan offstage —
      // su contenido no debe ser visible al usuario.
      expect(find.text('Cerrar sesión'), findsNothing);
      expect(find.byKey(const Key('templates.empty')), findsOneWidget);
    });

    testWidgets('un único destino Asistentes reemplaza Bots + Plantillas', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      Finder inNav(String label) => find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(label),
      );

      expect(inNav('Ataúlfo'), findsOneWidget);
      expect(inNav('Asistentes'), findsOneWidget);
      expect(inNav('Bots'), findsNothing);
      expect(inNav('Plantillas'), findsNothing);
      expect(inNav('Ajustes'), findsOneWidget);
    });

    testWidgets('Ajustes cierra la barra y Agenda es la penúltima (phone)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      final labels = nav.items.map((i) => i.label).toList();
      expect(labels.last, 'Ajustes');
      expect(labels[labels.length - 2], 'Agenda');
      expect(labels.first, 'Ataúlfo');
      expect(labels[1], 'Asistentes');
    });

    testWidgets('Ajustes cierra la barra y Agenda es la penúltima (rail)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      final labels = rail.destinations
          .map((d) => (d.label as Text).data)
          .toList();
      expect(labels.last, 'Ajustes');
      expect(labels[labels.length - 2], 'Agenda');
      expect(labels.first, 'Ataúlfo');
      expect(labels[1], 'Asistentes');
    });

    testWidgets('Asistentes (phone) muestra TemplatesListPage', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      expect(find.byType(TemplatesListPage), findsOneWidget);
      // El empty state de Templates (TemplatesLoaded([]) del stub) confirma
      // que el árbol del bloc llegó al widget.
      expect(find.byKey(const Key('templates.empty')), findsOneWidget);
    });

    testWidgets('Asistentes (tablet) muestra TemplatesListPage', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());
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

    testWidgets('Asistentes (phone) expone un único FAB de creación', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('shell.fab.template_create')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.fab.bot_create')), findsNothing);
    });

    testWidgets('Asistentes (tablet) expone el mismo FAB de creación', (
      tester,
    ) async {
      useViewport(tester, widthDp: 800);

      await tester.pumpWidget(host());

      expect(
        find.byKey(const Key('shell.fab.template_create')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.fab.bot_create')), findsNothing);
    });

    testWidgets('tab Etiquetas presente en BottomNavigationBar (phone)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());

      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap Etiquetas (phone) muestra LabelsAdminPage', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LabelsAdminPage), findsOneWidget);
      expect(find.byKey(const Key('labels_admin.empty')), findsOneWidget);
    });

    testWidgets('tab Etiquetas (phone) expone FAB de crear etiqueta', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell.fab.label_create')), findsOneWidget);
    });

    testWidgets('FAB de Etiquetas abre la hoja de creación', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shell.fab.label_create')));
      await tester.pumpAndSettle();

      expect(find.text('Nueva etiqueta'), findsOneWidget);
    });

    testWidgets('tab Ajustes no expone FAB', (tester) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell.fab.template_create')), findsNothing);
      expect(find.byKey(const Key('shell.fab.bot_create')), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('tap FAB en Asistentes abre la hoja de creación', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      final tplRepo = _MockTemplatesRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<TemplatesRepository>.value(
            value: tplRepo,
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<BotsBloc>.value(value: botsBloc),
                BlocProvider<TemplatesBloc>.value(value: templatesBloc),
                BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
              ],
              child: const ShellPage(),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('shell.fab.template_create')));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Asistente'), findsOneWidget);
    });

    testWidgets(
      'cambiar tab preserva el TemplatesBloc del shell (mismo instance)',
      (tester) async {
        useViewport(tester, widthDp: 420);

        await tester.pumpWidget(host());
        final blocBefore = tester
            .element(find.byType(TemplatesListPage))
            .read<TemplatesBloc>();
        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asistentes'));
        await tester.pumpAndSettle();
        final blocAfter = tester
            .element(find.byType(TemplatesListPage))
            .read<TemplatesBloc>();

        expect(identical(blocBefore, blocAfter), isTrue);
      },
    );
  });

  group('propagación del RouteObserver', () {
    // Para que el auto-refresh tras pop funcione, el shell tiene que
    // entregarle el observer al catálogo de Asistentes. El cableado vive en
    // el route builder del router (AppRouter), pero la prop se atraviesa
    // por ShellPage — éste test ancla esa prop como contrato del shell.
    testWidgets('ShellPage propaga el routeObserver a Asistentes', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      final observer = RouteObserver<PageRoute<dynamic>>();

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<BotsBloc>.value(value: botsBloc),
            BlocProvider<TemplatesBloc>.value(value: templatesBloc),
            BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
          ],
          child: MaterialApp(home: ShellPage(routeObserver: observer)),
        ),
      );

      final templatesList = tester.widget<TemplatesListPage>(
        find.byType(TemplatesListPage),
      );
      expect(templatesList.routeObserver, same(observer));
    });
  });

  group('header propio por tab', () {
    testWidgets('la tab Etiquetas NO monta AppBar del shell (header rico)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
      );
      await tester.pumpAndSettle();

      // Como Asistentes: la tarjeta-header full-bleed ES el encabezado.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('la tab Ajustes NO monta AppBar del shell (header propio)', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Ajustes'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('el avatar del header de Etiquetas navega a Ajustes', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);

      await tester.pumpWidget(host());
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Etiquetas'),
        ),
      );
      await tester.pumpAndSettle();

      final page = tester.widget<LabelsAdminPage>(find.byType(LabelsAdminPage));
      expect(
        page.onOpenSettings,
        isNotNull,
        reason: 'El shell debe cablear el avatar → tab Ajustes.',
      );
    });
  });

  group('pestaña Ataúlfo', () {
    Widget hostWithAssistant(_MockPaBloc pa) {
      // Estado terminal (sin spinner): solo verificamos que la página se monte
      // al abrir la tab. La carga real la cubre platform_agent_page_test.
      whenListen(
        pa,
        const Stream<PaChatState>.empty(),
        initialState: const PaChatFailed(PaServerFailure()),
      );
      return MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<BotsBloc>.value(value: botsBloc),
          BlocProvider<TemplatesBloc>.value(value: templatesBloc),
          BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
          BlocProvider<PlatformAgentChatBloc>.value(value: pa),
        ],
        child: const MaterialApp(home: ShellPage()),
      );
    }

    testWidgets(
      'tab Ataúlfo: se monta SOLO al abrirla (lazy en IndexedStack)',
      (tester) async {
        useViewport(tester, widthDp: 420);
        final pa = _MockPaBloc();
        await tester.pumpWidget(hostWithAssistant(pa));

        // Antes de abrir: el IndexedStack la sustituye por un SizedBox.
        expect(find.byType(PlatformAgentPage), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('Ataúlfo'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PlatformAgentPage), findsOneWidget);
      },
    );
  });
}
