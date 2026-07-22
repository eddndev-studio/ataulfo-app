import 'package:ataulfo/core/design/widgets/app_icon_pop.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/platform_agent/domain/failures/pa_failure.dart';
import 'package:ataulfo/features/platform_agent/presentation/bloc/platform_agent_chat_bloc.dart';
import 'package:ataulfo/features/platform_agent/presentation/pages/platform_agent_page.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
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

import '../../../../support/noop_profile_photo_cache.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

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
  late _MockTemplatesBloc templatesBloc;
  late _MockLabelsAdminBloc labelsBloc;
  late _MockConversationsBloc inboxBloc;
  late _MockMessagesRepository messagesRepository;
  late _MockChatLabelsRepository chatLabelsRepository;

  setUpAll(() {
    registerFallbackValue(const ConversationsLoadRequested());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    botsBloc = _MockBotsBloc();
    templatesBloc = _MockTemplatesBloc();
    labelsBloc = _MockLabelsAdminBloc();
    inboxBloc = _MockConversationsBloc();
    messagesRepository = _MockMessagesRepository();
    chatLabelsRepository = _MockChatLabelsRepository();
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(
      () => botsBloc.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));
    when(() => templatesBloc.state).thenReturn(
      const TemplatesLoaded(items: <Template>[], isRefreshing: false),
    );
    when(() => labelsBloc.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[], isRefreshing: false),
    );
    when(
      () => inboxBloc.state,
    ).thenReturn(const ConversationsState(phase: ConversationsPhase.ready));
  });

  Widget host({String assistantDraft = '', String? contextualBotId}) =>
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
              assistantDraft: assistantDraft,
              contextualBotId: contextualBotId,
              organizationContextBuilder: (_) => const SizedBox.shrink(),
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
        'Ataúlfo',
        'Ajustes',
      ]);
      expect(inBottomNav(find.text('Etiquetas')), findsNothing);
    });

    testWidgets('Agente solo ve Bandeja y Ajustes', (tester) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_workerIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());

      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.items.map((item) => item.label).toList(), <String>[
        'Bandeja',
        'Ajustes',
      ]);
      expect(inBottomNav(find.text('Asistentes')), findsNothing);
      expect(inBottomNav(find.text('Agenda')), findsNothing);
      expect(inBottomNav(find.text('Ataúlfo')), findsNothing);
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
        'Ataúlfo',
        'Ajustes',
      ]);
      expect(find.text('Asistentes'), findsNothing);
    });

    testWidgets('handoff a Ataúlfo no evade el rol Agente', (tester) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticated(_workerIdentity));
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host(assistantDraft: 'Crea una campaña'));

      expect(find.byType(ConversationsListPage), findsOneWidget);
      expect(find.byType(PlatformAgentPage), findsNothing);
      final nav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(nav.currentIndex, 0);
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

    testWidgets('Ajustes no expone FAB', (tester) async {
      useViewport(tester, widthDp: 420);
      await tester.pumpWidget(host());
      await tester.tap(inBottomNav(find.text('Ajustes')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
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

      await tester.tap(inBottomNav(find.text('Ajustes')));
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
      await tester.tap(inBottomNav(find.text('Ajustes')));
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

  group('Ataúlfo', () {
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

      await tester.pumpWidget(
        BlocProvider<PlatformAgentChatBloc>.value(value: pa, child: host()),
      );
      expect(find.byType(PlatformAgentPage), findsNothing);
      await tester.tap(inBottomNav(find.text('Ataúlfo')));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAgentPage), findsOneWidget);

      await tester.pumpWidget(
        BlocProvider<PlatformAgentChatBloc>.value(
          value: pa,
          child: host(assistantDraft: 'Crea una campaña'),
        ),
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
