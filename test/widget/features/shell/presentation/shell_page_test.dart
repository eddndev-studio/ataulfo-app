import 'package:ataulfo/core/design/widgets/app_icon_pop.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/calendar/presentation/bloc/agenda_cubit.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/presentation/bloc/memberships_bloc.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/shell/presentation/pages/shell_page.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/templates_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/noop_profile_photo_cache.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockMembershipsBloc extends MockBloc<MembershipsEvent, MembershipsState>
    implements MembershipsBloc {}

class _MockSwitchOrgCubit extends MockCubit<SwitchOrgState>
    implements SwitchOrgCubit {}

class _MockAgendaCubit extends MockCubit<AgendaState> implements AgendaCubit {}

class _MockTemplatesBloc extends MockBloc<TemplatesEvent, TemplatesState>
    implements TemplatesBloc {}

class _MockLabelsAdminBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

class _MockPaBloc extends MockBloc<PaChatEvent, PaChatState>
    implements PlatformAgentChatBloc {}

class _MockTemplatesRepository extends Mock implements TemplatesRepository {}

class _MockMessagesRepository extends Mock implements MessagesRepository {}

class _MockChatLabelsRepository extends Mock implements ChatLabelsRepository {}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

const _workerIdentity = Identity(
  userId: 'u2',
  orgId: 'o1',
  role: 'WORKER',
  email: 'agente@example.com',
  emailVerified: true,
);

const _supervisorIdentity = Identity(
  userId: 'u3',
  orgId: 'o1',
  role: 'SUPERVISOR',
  email: 'supervisor@example.com',
  emailVerified: true,
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsBloc botsBloc;
  late _MockMembershipsBloc membershipsBloc;
  late _MockSwitchOrgCubit switchOrgCubit;
  late _MockAgendaCubit agendaCubit;
  late _MockTemplatesBloc templatesBloc;
  late _MockLabelsAdminBloc labelsBloc;
  late _MockConversationsBloc inboxBloc;
  late _MockPaBloc paBloc;
  late _MockMessagesRepository messagesRepository;
  late _MockChatLabelsRepository chatLabelsRepository;

  setUpAll(() {
    registerFallbackValue(const ConversationsLoadRequested());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    botsBloc = _MockBotsBloc();
    membershipsBloc = _MockMembershipsBloc();
    switchOrgCubit = _MockSwitchOrgCubit();
    agendaCubit = _MockAgendaCubit();
    templatesBloc = _MockTemplatesBloc();
    labelsBloc = _MockLabelsAdminBloc();
    inboxBloc = _MockConversationsBloc();
    paBloc = _MockPaBloc();
    messagesRepository = _MockMessagesRepository();
    chatLabelsRepository = _MockChatLabelsRepository();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
    when(() => membershipsBloc.state).thenReturn(
      const MembershipsLoaded(
        items: <Membership>[
          Membership(orgId: 'o1', orgName: 'Ataúlfo Studio', role: 'OWNER'),
          Membership(orgId: 'o2', orgName: 'Taller Mango', role: 'ADMIN'),
        ],
      ),
    );
    when(() => switchOrgCubit.state).thenReturn(const SwitchOrgIdle());
    when(() => agendaCubit.state).thenReturn(
      AgendaState(
        day: DateTime(2026, 7, 23),
        status: AgendaStatus.loaded,
        appointments: const [],
        failure: null,
        mutating: false,
      ),
    );
    when(() => templatesBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );
    when(() => labelsBloc.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false),
    );
    when(
      () => inboxBloc.state,
    ).thenReturn(const ConversationsState(phase: ConversationsPhase.ready));
    whenListen(
      paBloc,
      const Stream<PaChatState>.empty(),
      initialState: const PaChatFailed(PaServerFailure()),
    );
  });

  Widget host({
    String assistantDraft = '',
    String? contextualBotId,
    bool realOrganizationContext = false,
    PlatformAgentChatBloc? platformAgentBloc,
  }) => MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<ProfilePhotoCache>.value(
        value: NoopProfilePhotoCache(),
      ),
      RepositoryProvider<MessagesRepository>.value(value: messagesRepository),
      RepositoryProvider<ChatLabelsRepository>.value(
        value: chatLabelsRepository,
      ),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<BotsBloc>.value(value: botsBloc),
        BlocProvider<MembershipsBloc>.value(value: membershipsBloc),
        BlocProvider<SwitchOrgCubit>.value(value: switchOrgCubit),
        BlocProvider<AgendaCubit>.value(value: agendaCubit),
        BlocProvider<TemplatesBloc>.value(value: templatesBloc),
        BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
        BlocProvider<ConversationsBloc>.value(value: inboxBloc),
        BlocProvider<PlatformAgentChatBloc>.value(
          value: platformAgentBloc ?? paBloc,
        ),
      ],
      child: MaterialApp(
        home: ShellPage(
          assistantDraft: assistantDraft,
          contextualBotId: contextualBotId,
          organizationContextBuilder: realOrganizationContext
              ? null
              : (compact) => SizedBox(
                  key: Key(
                    compact
                        ? 'test.organization.header'
                        : 'test.organization.drawer',
                  ),
                ),
        ),
      ),
    ),
  );

  void useViewport(WidgetTester tester, {required double widthDp}) {
    const dpr = 3.0;
    tester.view.physicalSize = Size(widthDp * dpr, 800 * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder inBottomNav(Finder matching) =>
      find.descendant(of: find.byType(BottomNavigationBar), matching: matching);

  group('destinos principales', () {
    testWidgets('Bandeja es el destino inicial y conserva el orden acordado', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      expect(find.byType(ConversationsListPage), findsOneWidget);
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.map((item) => item.label).toList(), <String>[
        'Bandeja',
        'Asistentes',
        'Agenda',
        'Copiloto',
      ]);
      expect(inBottomNav(find.text('Etiquetas')), findsNothing);
      expect(inBottomNav(find.text('Ajustes')), findsNothing);
    });

    testWidgets('Agente solo ve Bandeja y no necesita navegación primaria', (
      tester,
    ) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_workerIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      expect(find.byType(ConversationsListPage), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Supervisor ve operación global pero no Asistentes', (
      tester,
    ) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_supervisorIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.map((item) => item.label).toList(), <String>[
        'Bandeja',
        'Agenda',
        'Copiloto',
      ]);
      expect(find.text('Asistentes'), findsNothing);
      expect(inBottomNav(find.text('Ajustes')), findsNothing);
    });

    testWidgets('handoff a Copiloto no evade el rol Agente', (tester) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_workerIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host(assistantDraft: 'Crea una campaña'));

      expect(find.byType(ConversationsListPage), findsOneWidget);
      expect(find.byType(PlatformAgentPage), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('la selección usa ícono filled + AppIconPop', (tester) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      expect(inBottomNav(find.byIcon(Icons.inbox)), findsOneWidget);
      expect(inBottomNav(find.byType(AppIconPop)), findsOneWidget);
      expect(inBottomNav(find.byIcon(Icons.inbox_outlined)), findsNothing);

      await tester.tap(inBottomNav(find.text('Asistentes')));
      await tester.pumpAndSettle();
      expect(inBottomNav(find.byIcon(Icons.inbox_outlined)), findsOneWidget);
      expect(inBottomNav(find.byIcon(Icons.support_agent)), findsOneWidget);
    });

    testWidgets('phone usa barra inferior y tablet usa rail', (tester) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      useViewport(tester, widthDp: 800);
      await tester.pumpWidget(host());
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('Asistentes conserva su catálogo y FAB contextual', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(inBottomNav(find.text('Asistentes')));
      await tester.pumpAndSettle();
      expect(find.byType(TemplatesListPage), findsOneWidget);
      expect(
        find.byKey(const Key('shell.fab.template_create')),
        findsOneWidget,
      );
    });

    testWidgets('header nombra la sección y el menú concentra gestión', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      expect(find.text('Bandeja'), findsWidgets);
      expect(find.byKey(const Key('test.organization.header')), findsNothing);

      await tester.tap(find.byKey(const Key('shell.header.menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell.drawer')), findsOneWidget);
      expect(find.byKey(const Key('shell.drawer.brand.mango')), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byKey(const Key('test.organization.drawer')), findsOneWidget);
      expect(
        find.byKey(const Key('shell.drawer.organization')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.drawer.library')), findsOneWidget);
      expect(find.byKey(const Key('shell.drawer.labels')), findsOneWidget);
      expect(find.byKey(const Key('shell.drawer.settings')), findsOneWidget);
      expect(
        find.byKey(const Key('shell.drawer.notifications')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.drawer.appearance')), findsOneWidget);
    });

    testWidgets(
      'las cuatro tabs comparten eje de menú y título en el app bar',
      (tester) async {
        useViewport(tester, widthDp: 420);
        await tester.pumpWidget(host());

        ({Offset menu, Offset title}) geometry(String title) {
          final header = find
              .byKey(const Key('app_page_header.surface'))
              .hitTestable();
          expect(header, findsOneWidget);
          final menu = find.descendant(
            of: header,
            matching: find.byKey(const Key('shell.header.menu')),
          );
          final heading = find.descendant(
            of: header,
            matching: find.text(title),
          );
          expect(menu, findsOneWidget);
          expect(heading, findsOneWidget);
          return (
            menu: tester.getCenter(menu),
            title: tester.getTopLeft(heading),
          );
        }

        final inbox = geometry('Bandeja');
        await tester.tap(inBottomNav(find.text('Asistentes')));
        await tester.pumpAndSettle();
        final assistants = geometry('Asistentes');
        await tester.tap(inBottomNav(find.text('Agenda')));
        await tester.pumpAndSettle();
        final agenda = geometry('Agenda');
        await tester.tap(inBottomNav(find.text('Copiloto')));
        await tester.pumpAndSettle();
        final copilot = geometry('Copiloto');

        for (final candidate in <({Offset menu, Offset title})>[
          assistants,
          agenda,
          copilot,
        ]) {
          expect(candidate.menu.dx, closeTo(inbox.menu.dx, 0.1));
          expect(candidate.menu.dy, closeTo(inbox.menu.dy, 0.1));
          expect(candidate.title.dx, closeTo(inbox.title.dx, 0.1));
          expect(candidate.title.dy, closeTo(inbox.title.dy, 0.1));
        }
      },
    );

    testWidgets('drawer de Agente oculta gestión sin privilegios', (
      tester,
    ) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_workerIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('shell.header.menu')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('shell.drawer.organization')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell.drawer.library')), findsNothing);
      expect(find.byKey(const Key('shell.drawer.labels')), findsNothing);
      expect(find.byKey(const Key('shell.drawer.settings')), findsOneWidget);
    });

    testWidgets(
      'selector de organización se apila y al descartarlo conserva el drawer',
      (tester) async {
        useViewport(tester, widthDp: 420);
        await tester.pumpWidget(host(realOrganizationContext: true));

        await tester.tap(find.byKey(const Key('shell.header.menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('organization.context.drawer')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('shell.drawer')), findsOneWidget);
        expect(find.text('Cambiar organización'), findsOneWidget);
        expect(
          find.byKey(const Key('organization.switch.close')),
          findsNothing,
        );

        final bottomSheet = tester.widget<BottomSheet>(
          find.byType(BottomSheet),
        );
        expect(bottomSheet.showDragHandle, isTrue);
        expect(bottomSheet.enableDrag, isTrue);

        await tester.tapAt(const Offset(410, 48));
        await tester.pumpAndSettle();

        expect(find.text('Cambiar organización'), findsNothing);
        expect(find.byKey(const Key('shell.drawer')), findsOneWidget);

        await tester.tap(find.byKey(const Key('organization.context.drawer')));
        await tester.pumpAndSettle();
        final sheetBounds = tester.getRect(find.byType(BottomSheet));
        await tester.dragFrom(
          Offset(sheetBounds.center.dx, sheetBounds.top + 12),
          const Offset(0, 400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cambiar organización'), findsNothing);
        expect(find.byKey(const Key('shell.drawer')), findsOneWidget);
      },
    );
  });

  group('preservación de estado', () {
    testWidgets('cambiar de tab conserva la instancia de Bandeja', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());
      final before = tester
          .element(find.byType(ConversationsListPage))
          .read<ConversationsBloc>();

      await tester.tap(inBottomNav(find.text('Asistentes')));
      await tester.pumpAndSettle();
      await tester.tap(inBottomNav(find.text('Bandeja')));
      await tester.pumpAndSettle();

      final after = tester
          .element(find.byType(ConversationsListPage))
          .read<ConversationsBloc>();
      expect(after, same(before));
    });

    testWidgets('un Canal contextual vivo abre Bandeja y aplica su filtro', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());
      await tester.tap(inBottomNav(find.text('Asistentes')));
      await tester.pumpAndSettle();
      clearInteractions(inboxBloc);

      await tester.pumpWidget(host(contextualBotId: 'bot-ventas'));
      await tester.pump();

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.currentIndex, 0);
      final event =
          verify(
                () => inboxBloc.add(
                  captureAny(that: isA<ConversationsChannelChanged>()),
                ),
              ).captured.single
              as ConversationsChannelChanged;
      expect(event.botId, 'bot-ventas');
    });

    testWidgets('ShellPage propaga el routeObserver a Asistentes', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      final observer = RouteObserver<PageRoute<dynamic>>();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: <RepositoryProvider<dynamic>>[
            RepositoryProvider<ProfilePhotoCache>.value(
              value: NoopProfilePhotoCache(),
            ),
            RepositoryProvider<MessagesRepository>.value(
              value: messagesRepository,
            ),
            RepositoryProvider<ChatLabelsRepository>.value(
              value: chatLabelsRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<BotsBloc>.value(value: botsBloc),
              BlocProvider<TemplatesBloc>.value(value: templatesBloc),
              BlocProvider<LabelsAdminBloc>.value(value: labelsBloc),
              BlocProvider<ConversationsBloc>.value(value: inboxBloc),
            ],
            child: MaterialApp(
              home: ShellPage(
                routeObserver: observer,
                organizationContextBuilder: (_) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(inBottomNav(find.text('Asistentes')));
      await tester.pumpAndSettle();

      final page = tester.widget<TemplatesListPage>(
        find.byType(TemplatesListPage),
      );
      expect(page.routeObserver, same(observer));
    });
  });

  group('Copiloto', () {
    testWidgets('sigue lazy y un handoff contextual lo abre directamente', (
      tester,
    ) async {
      useViewport(tester, widthDp: 420);
      final pa = _MockPaBloc();
      whenListen(
        pa,
        const Stream<PaChatState>.empty(),
        initialState: const PaChatFailed(PaServerFailure()),
      );

      await tester.pumpWidget(host(platformAgentBloc: pa));
      expect(find.byType(PlatformAgentPage), findsNothing);
      await tester.tap(inBottomNav(find.text('Copiloto')));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAgentPage), findsOneWidget);

      await tester.pumpWidget(
        host(assistantDraft: 'Crea una campaña', platformAgentBloc: pa),
      );
      await tester.pump();
      expect(find.byType(PlatformAgentPage), findsOneWidget);
    });
  });

  testWidgets('FAB de Asistentes abre la hoja de creación', (tester) async {
    useViewport(tester, widthDp: 420);
    final templatesRepository = _MockTemplatesRepository();
    await tester.pumpWidget(
      RepositoryProvider<TemplatesRepository>.value(
        value: templatesRepository,
        child: host(),
      ),
    );
    await tester.tap(inBottomNav(find.text('Asistentes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shell.fab.template_create')));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo Asistente'), findsOneWidget);
  });
}
