import 'dart:async';

import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/router/app_router.dart';
import 'package:ataulfo/features/ai_catalog/domain/entities/catalog.dart';
import 'package:ataulfo/features/ai_catalog/domain/repositories/catalog_repository.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/domain/repositories/auth_repository.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/auth/presentation/bloc/rename_org_cubit.dart';
import 'package:ataulfo/features/auth/presentation/bloc/switch_org_cubit.dart';
import 'package:ataulfo/features/auth/presentation/pages/accept_invite_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/create_org_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/login_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/register_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/reset_password_page.dart';
import 'package:ataulfo/features/auth/presentation/pages/verify_email_page.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/entities/bot_variables_snapshot.dart';
import 'package:ataulfo/features/bots/domain/repositories/bot_session_repository.dart';
import 'package:ataulfo/features/bots/domain/repositories/bots_repository.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_create_page.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_maintenance_page.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_template_picker_page.dart';
import 'package:ataulfo/features/bots/presentation/pages/bot_variables_page.dart';
import 'package:ataulfo/features/bots/presentation/pages/bots_list_page.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/flows/domain/entities/flow.dart' as fdom;
import 'package:ataulfo/features/flows/domain/repositories/flows_repository.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/media/domain/repositories/media_repository.dart';
import 'package:ataulfo/features/invitations/domain/entities/invitation.dart';
import 'package:ataulfo/features/invitations/domain/repositories/invitations_repository.dart';
import 'package:ataulfo/features/invitations/presentation/bloc/invitation_mutation_cubit.dart';
import 'package:ataulfo/features/invitations/presentation/pages/invitations_page.dart';
import 'package:ataulfo/features/members/domain/entities/member.dart';
import 'package:ataulfo/features/members/domain/repositories/members_repository.dart';
import 'package:ataulfo/features/members/presentation/bloc/member_mutation_cubit.dart';
import 'package:ataulfo/features/members/presentation/pages/bot_assignment_page.dart';
import 'package:ataulfo/features/members/presentation/pages/members_page.dart';
import 'package:ataulfo/features/memberships/domain/entities/membership.dart';
import 'package:ataulfo/features/memberships/domain/repositories/memberships_repository.dart';
import 'package:ataulfo/features/memberships/presentation/pages/memberships_page.dart';
import 'package:ataulfo/features/memberships/presentation/pages/select_org_page.dart';
import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/message_page.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/messages/presentation/pages/message_thread_page.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_inbox_item.dart';
import 'package:ataulfo/features/notifications/domain/entities/notification_preference.dart';
import 'package:ataulfo/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:ataulfo/features/notifications/presentation/pages/notification_preferences_page.dart';
import 'package:ataulfo/features/notifications/presentation/pages/notifications_page.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/domain/repositories/profile_repository.dart';
import 'package:ataulfo/features/profile/presentation/pages/profile_page.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:ataulfo/features/templates/domain/entities/template.dart';
import 'package:ataulfo/features/templates/domain/entities/variable_def.dart';
import 'package:ataulfo/features/templates/domain/repositories/templates_repository.dart';
import 'package:ataulfo/features/templates/presentation/bloc/templates_bloc.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_create_page.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_detail_page.dart';
import 'package:ataulfo/features/templates/presentation/pages/template_edit_page.dart';
import 'package:ataulfo/features/triggers/domain/entities/trigger.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/labels_repository.dart';
import 'package:ataulfo/features/triggers/domain/repositories/triggers_repository.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_thumbnail_loader.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

class _MockBotSessionRepo extends Mock implements BotSessionRepository {}

class _MockConversationsRepo extends Mock implements ConversationsRepository {}

class _MockMessagesRepo extends Mock implements MessagesRepository {}

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _MockTemplatesRepo extends Mock implements TemplatesRepository {}

class _MockFlowsRepo extends Mock implements FlowsRepository {}

class _MockTriggersRepo extends Mock implements TriggersRepository {}

class _MockLabelsRepo extends Mock implements LabelsRepository {}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

class _MockMembershipsRepo extends Mock implements MembershipsRepository {}

class _MockMembersRepo extends Mock implements MembersRepository {}

class _MockInvitationsRepo extends Mock implements InvitationsRepository {}

class _MockCatalogRepo extends Mock implements CatalogRepository {}

class _MockMediaRepo extends Mock implements MediaRepository {}

class _MockNotificationsRepo extends Mock implements NotificationsRepository {}

class _FakeMediaFilePicker implements MediaFilePicker {
  @override
  Future<PickedMedia?> pick() async => null;
}

const _identity = Identity(
  userId: 'u1',
  orgId: 'o1',
  role: 'OWNER',
  email: 'op@example.com',
);

const _worker = Identity(
  userId: 'u2',
  orgId: 'o1',
  role: 'WORKER',
  email: 'worker@example.com',
);

const _noOrg = Identity(
  userId: 'u3',
  orgId: '',
  role: '',
  email: 'op@example.com',
);

// Dos identidades del MISMO usuario en orgs distintas: alimentan el test del
// re-key del shell, que destruye y recrea los blocs org-scoped al cambiar de
// org (datos de la org vieja no deben sobrevivir al switch).
const _orgA = Identity(
  userId: 'u1',
  orgId: 'o-A',
  role: 'OWNER',
  email: 'op@example.com',
);

const _orgB = Identity(
  userId: 'u1',
  orgId: 'o-B',
  role: 'OWNER',
  email: 'op@example.com',
);

// Mismo orgId que _orgA, sólo cambia emailVerified: un refresh de /auth/me que
// sólo confirme el correo NO debe reconstruir el shell (el banner de
// verificación vive de updates de identity sin tirar las listas).
const _orgAVerified = Identity(
  userId: 'u1',
  orgId: 'o-A',
  role: 'OWNER',
  email: 'op@example.com',
  emailVerified: true,
);

const _profile = ChatProfile(
  chatLid: 'lid-1',
  isGroup: false,
  phone: '5215550001',
  displayName: null,
  photoUrl: null,
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

Widget _host(AppRouter router, AuthBloc authBloc) =>
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router.router),
    );

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsRepo botsRepo;
  late _MockBotSessionRepo botSessionRepo;
  late _MockConversationsRepo conversationsRepo;
  late _MockMessagesRepo messagesRepo;
  late _MockProfileRepo profileRepo;
  late _MockTemplatesRepo templatesRepo;
  late _MockFlowsRepo flowsRepo;
  late _MockTriggersRepo triggersRepo;
  late _MockMembershipsRepo membershipsRepo;
  late _MockMembersRepo membersRepo;
  late _MockInvitationsRepo invitationsRepo;
  late _MockCatalogRepo catalogRepo;
  late _MockLabelsRepo labelsRepo;
  late _MockNotificationsRepo notificationsRepo;
  late AppRouter router;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsRepo = _MockBotsRepo();
    botSessionRepo = _MockBotSessionRepo();
    conversationsRepo = _MockConversationsRepo();
    messagesRepo = _MockMessagesRepo();
    profileRepo = _MockProfileRepo();
    templatesRepo = _MockTemplatesRepo();
    flowsRepo = _MockFlowsRepo();
    triggersRepo = _MockTriggersRepo();
    membershipsRepo = _MockMembershipsRepo();
    membersRepo = _MockMembersRepo();
    invitationsRepo = _MockInvitationsRepo();
    catalogRepo = _MockCatalogRepo();
    labelsRepo = _MockLabelsRepo();
    notificationsRepo = _MockNotificationsRepo();
    // Los blocs page-scoped del shell arrancan con LoadRequested al
    // construirse; los repos mock devuelven listas vacías para que los
    // loads terminen sin colgar el pumpAndSettle. El CatalogBloc se
    // monta en /templates/:id/edit (TE3) — un catálogo vacío basta
    // para los smoke tests del router (los tests del editor están en
    // su propio widget test).
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    when(templatesRepo.list).thenAnswer((_) async => const <Template>[]);
    // El detalle del bot, para un rol ADMIN+, monta el toggle de IA que lee
    // Template.ai.enabled (IA efectiva). El _identity de estos tests es OWNER,
    // así que la ruta /bots/:id fetchea la Template — un stub la resuelve.
    when(() => templatesRepo.byId(any())).thenAnswer(
      (_) async => const Template(
        id: 't1',
        orgId: 'o1',
        name: 'Plantilla',
        version: 1,
        ai: AIConfig(
          enabled: true,
          provider: AIProvider.openai,
          model: 'gpt',
          temperature: 0.7,
          thinkingLevel: ThinkingLevel.medium,
          systemPrompt: '',
          contextMessages: 10,
        ),
      ),
    );
    when(
      () => flowsRepo.listFlows(any()),
    ).thenAnswer((_) async => const <fdom.Flow>[]);
    when(
      () => triggersRepo.listTriggers(any()),
    ).thenAnswer((_) async => const <Trigger>[]);
    when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);
    when(membersRepo.list).thenAnswer((_) async => const <Member>[]);
    when(invitationsRepo.list).thenAnswer((_) async => const <Invitation>[]);
    // El LabelsAdminBloc de la tab Etiquetas del shell dispara listLabels al
    // construirse; un catálogo vacío deja terminar el pumpAndSettle.
    when(labelsRepo.listLabels).thenAnswer((_) async => const <Label>[]);
    when(
      () => notificationsRepo.listInbox(unreadOnly: true),
    ).thenAnswer((_) async => const <NotificationInboxItem>[]);
    when(
      notificationsRepo.listPreferences,
    ).thenAnswer((_) async => const <NotificationPreference>[]);
    when(
      catalogRepo.fetch,
    ).thenAnswer((_) async => const Catalog(providers: <ProviderEntry>[]));
    // El hilo de mensajes (S15) se suscribe al stream en vivo tras cargar la
    // cola; un stream vacío deja terminar el pumpAndSettle sin emitir nada.
    when(
      () => messagesRepo.live(any()),
    ).thenAnswer((_) => const Stream<ThreadLiveEvent>.empty());
    // El hilo monta un ProfileBloc que dispara fetch al construirse (alimenta
    // el header); un perfil terminal deja que pumpAndSettle termine.
    when(
      () => profileRepo.fetch(any(), any()),
    ).thenAnswer((_) async => _profile);
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );
  });

  testWidgets('AuthInitial → Splash (CircularProgressIndicator)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthInitial());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /home muestra BotsListPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(BotsListPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /home expone TemplatesBloc al árbol', (
    tester,
  ) async {
    // El provider del TemplatesBloc vive en el route builder de /home (no
    // dentro de cada tab) para preservarlo entre cambios de tab. Si lo
    // mueven adentro del shell, este test rompe — guarda el contrato.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    // Leer el bloc desde el árbol del BotsListPage (tab activa por
    // default) confirma que el provider está aguas arriba del shell.
    final templatesBloc = tester
        .element(find.byType(BotsListPage))
        .read<TemplatesBloc>();
    expect(templatesBloc, isNotNull);
    // El bloc dispara LoadRequested al construirse; el repo mock responde
    // con [] y el bloc termina en Loaded(empty). pumpAndSettle ya esperó
    // la transición.
    verify(templatesRepo.list).called(1);
  });

  testWidgets('AuthUnauthenticated → redirige a LoginPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'cambio de estado dispara refreshListenable y re-evalúa redirect',
    (tester) async {
      whenListen(
        authBloc,
        Stream<AuthState>.fromIterable(const <AuthState>[
          AuthUnauthenticated(),
          AuthAuthenticated(_identity),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(BotsListPage), findsOneWidget);
    },
  );

  testWidgets(
    'cambiar de org reconstruye el shell: los blocs org-scoped recargan datos '
    'de la org nueva (botsRepo.list dos veces)',
    (tester) async {
      // El shell /home se re-keyea por orgId: cuando el orgId activo cambia,
      // el subárbol (MultiBlocProvider incluido) se destruye y recrea, y los
      // blocs page-scoped vuelven a cargar — la lista de la org vieja no debe
      // sobrevivir al switch. Drive controlado: montar bajo o-A (load #1),
      // settle, EMITIR o-B y settle (load #2). Sin el controlador, ambas
      // emisiones podrían coalescer antes del primer build y dar un falso
      // called(1).
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);
      whenListen(
        authBloc,
        controller.stream,
        initialState: const AuthAuthenticated(_orgA),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(BotsListPage), findsOneWidget);

      controller.add(const AuthAuthenticated(_orgB));
      await tester.pumpAndSettle();

      verify(botsRepo.list).called(2);
    },
  );

  testWidgets(
    'refresh que sólo cambia emailVerified (mismo orgId) NO reconstruye el '
    'shell (botsRepo.list una vez)',
    (tester) async {
      // Guarda contra el over-rebuild: el shell se keyea por orgId SOLO, no por
      // la identity completa. Un /auth/me que sólo confirme el correo deja el
      // mismo orgId, así que el subárbol se conserva y los blocs NO recargan
      // (el banner de verificación se actualiza sin nukear las listas).
      final controller = StreamController<AuthState>();
      addTearDown(controller.close);
      whenListen(
        authBloc,
        controller.stream,
        initialState: const AuthAuthenticated(_orgA),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(BotsListPage), findsOneWidget);

      controller.add(const AuthAuthenticated(_orgAVerified));
      await tester.pumpAndSettle();

      verify(botsRepo.list).called(1);
    },
  );

  testWidgets('AuthAuthenticated → /bots/:id muestra BotDetailPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    // El BotDetailBloc de la ruta arranca con LoadRequested al construirse;
    // el repo mock devuelve un Bot para que el load termine sin colgar
    // pumpAndSettle.
    when(() => botsRepo.byId('b1')).thenAnswer(
      (_) async => const Bot(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
        identifier: '52155...',
        version: 3,
        paused: false,
        aiDisabled: false,
      ),
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(BotDetailPage), findsOneWidget);
    verify(() => botsRepo.byId('b1')).called(1);
  });

  testWidgets(
    'AuthAuthenticated(OWNER) → /bots/:id/variables monta BotVariablesPage',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      // El editor carga vía getVariables (version+templateId+overrides), no byId.
      when(() => botsRepo.getVariables('b1')).thenAnswer(
        (_) async => const BotVariablesSnapshot(
          version: 3,
          templateId: 't1',
          values: <String, String>{},
        ),
      );
      when(() => templatesRepo.listVarDefs('t1')).thenAnswer(
        (_) async => (
          version: 9,
          defs: const <VariableDef>[
            VariableDef(
              id: 'v1',
              name: 'tono',
              defaultValue: 'neutral',
              description: 'Tono',
            ),
          ],
        ),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/variables');
      await tester.pumpAndSettle();

      expect(find.byType(BotVariablesPage), findsOneWidget);
    },
  );

  testWidgets('WORKER deep-link a /bots/:id/variables → redirige al detalle', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_worker));
    when(() => botsRepo.byId('b1')).thenAnswer(
      (_) async => const Bot(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
        identifier: null,
        version: 3,
        paused: false,
        aiDisabled: false,
      ),
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1/variables');
    await tester.pumpAndSettle();

    // El gateo ADMIN+ del redirect lo desvía al detalle; el editor no monta.
    expect(find.byType(BotVariablesPage), findsNothing);
    expect(find.byType(BotDetailPage), findsOneWidget);
    // Y NUNCA fetchea las var-defs (la ruta ni se montó).
    verifyNever(() => templatesRepo.listVarDefs(any()));
  });

  testWidgets(
    'AuthAuthenticated(OWNER) → /bots/:id/maintenance monta BotMaintenancePage',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      when(() => botsRepo.byId('b1')).thenAnswer(
        (_) async => const Bot(
          id: 'b1',
          orgId: 'o1',
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
          identifier: null,
          version: 3,
          paused: true,
          aiDisabled: false,
        ),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/maintenance');
      await tester.pumpAndSettle();

      expect(find.byType(BotMaintenancePage), findsOneWidget);
    },
  );

  testWidgets(
    'WORKER deep-link a /bots/:id/maintenance → redirige al detalle',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_worker));
      when(() => botsRepo.byId('b1')).thenAnswer(
        (_) async => const Bot(
          id: 'b1',
          orgId: 'o1',
          templateId: 't1',
          name: 'Soporte',
          channel: BotChannel.waUnofficial,
          identifier: null,
          version: 3,
          paused: true,
          aiDisabled: false,
        ),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/maintenance');
      await tester.pumpAndSettle();

      expect(find.byType(BotMaintenancePage), findsNothing);
      expect(find.byType(BotDetailPage), findsOneWidget);
    },
  );

  testWidgets(
    'AuthAuthenticated → /bots/:id/sessions monta ConversationsListPage con el botId',
    (tester) async {
      // Bloquea el seam que ningún test de widget alcanza: la ruta debe sembrar
      // el ConversationsBloc con el botId del path Y disparar el load al montar.
      // Un typo de path, repo equivocado o ..add(load) caído daría spinner
      // infinito que el widget test (que inyecta un bloc mock) no detecta.
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      when(
        () => conversationsRepo.listForBot('b1'),
      ).thenAnswer((_) async => const <Conversation>[]);

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/sessions');
      await tester.pumpAndSettle();

      expect(find.byType(ConversationsListPage), findsOneWidget);
      verify(() => conversationsRepo.listForBot('b1')).called(1);
    },
  );

  testWidgets(
    'AuthAuthenticated → /bots/:id/sessions/:chatLid monta MessageThreadPage '
    'sembrando botId+chatLid',
    (tester) async {
      // Seam del hilo: la ruta debe sembrar el MessagesBloc con botId Y chatLid
      // del path y disparar el load (la cola) al montar. Un typo de path, repo
      // equivocado o ..add(load) caído daría spinner infinito que el widget
      // test (bloc mock) no detecta.
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      when(
        () => messagesRepo.thread('b1', 'lid-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const MessagePage(messages: <Message>[], prevCursor: null),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/sessions/lid-1');
      await tester.pumpAndSettle();

      expect(find.byType(MessageThreadPage), findsOneWidget);
      verify(
        () => messagesRepo.thread('b1', 'lid-1', cursor: null, limit: null),
      ).called(1);
    },
  );

  testWidgets(
    'tap en una conversación navega a su hilo (/bots/:id/sessions/:chatLid)',
    (tester) async {
      // El tap de la fila empuja la ruta del hilo con el chatLid de la
      // conversación; confirma el cableado fila→navegación end-to-end.
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      when(() => conversationsRepo.listForBot('b1')).thenAnswer(
        (_) async => const <Conversation>[
          Conversation(
            chatLid: 'lid-1',
            kind: ConversationKind.dm,
            phone: '5215550001',
            isArchived: false,
            isPinned: false,
            isMarkedUnread: false,
            mutedUntil: null,
          ),
        ],
      );
      when(
        () => messagesRepo.thread('b1', 'lid-1', cursor: null, limit: null),
      ).thenAnswer(
        (_) async => const MessagePage(messages: <Message>[], prevCursor: null),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/bots/b1/sessions');
      await tester.pumpAndSettle();

      await tester.tap(find.text('5215550001'));
      await tester.pumpAndSettle();

      expect(find.byType(MessageThreadPage), findsOneWidget);
      verify(
        () => messagesRepo.thread('b1', 'lid-1', cursor: null, limit: null),
      ).called(1);
    },
  );

  testWidgets('tap en el header del hilo abre la pantalla de perfil', (
    tester,
  ) async {
    // Seam header→perfil: el app bar del hilo (ChatThreadAppBar) es tappable y
    // empuja la ruta de perfil, que monta ProfilePage. Un typo de path o un
    // header no-tappable rompería el "revisar perfil" sin que los widget tests
    // aislados lo noten.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(
      () => messagesRepo.thread('b1', 'lid-1', cursor: null, limit: null),
    ).thenAnswer(
      (_) async => const MessagePage(messages: <Message>[], prevCursor: null),
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1/sessions/lid-1');
    await tester.pumpAndSettle();
    expect(find.byType(ChatThreadAppBar), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ChatThreadAppBar),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('AuthUnauthenticated + ruta protegida cualquiera → /login', (
    tester,
  ) async {
    // El redirect no debe asumir que /home es el único destino protegido:
    // cualquier ruta no pública (p. ej. /bots/:id por deep-link) tiene que
    // mandar a /login si no hay sesión.
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(BotDetailPage), findsNothing);
  });

  testWidgets('AuthAuthenticated → /templates/:id muestra TemplateDetailPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    // El TemplateDetailBloc y el VarDefsBloc de la ruta arrancan ambos con
    // LoadRequested al construirse; los repos mock devuelven valores
    // terminales para que pumpAndSettle no cuelgue.
    when(() => templatesRepo.byId('t1')).thenAnswer(
      (_) async => const Template(
        id: 't1',
        orgId: 'o1',
        name: 'Soporte',
        version: 1,
        ai: AIConfig(
          enabled: false,
          provider: AIProvider.gemini,
          model: 'gemini-3.1-pro-preview',
          temperature: 0.7,
          thinkingLevel: ThinkingLevel.low,
          systemPrompt: '',
          contextMessages: 20,
        ),
      ),
    );
    when(
      () => templatesRepo.listVarDefs('t1'),
    ).thenAnswer((_) async => (version: 1, defs: const <VariableDef>[]));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/templates/t1');
    await tester.pumpAndSettle();

    expect(find.byType(TemplateDetailPage), findsOneWidget);
    verify(() => templatesRepo.byId('t1')).called(1);
    // El VarDefsBloc del route builder dispara su propio LoadRequested al
    // construirse; sin este verify, un futuro slice podría dejar el bloc
    // huérfano (sin load) sin romper otros tests.
    verify(() => templatesRepo.listVarDefs('t1')).called(1);
  });

  testWidgets('AuthAuthenticated → /templates/new muestra TemplateCreatePage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/templates/new');
    await tester.pumpAndSettle();

    expect(find.byType(TemplateCreatePage), findsOneWidget);
  });

  testWidgets('AuthUnauthenticated + deep-link a /templates/new → /login', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/templates/new');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TemplateCreatePage), findsNothing);
  });

  testWidgets('AuthUnauthenticated + deep-link a /templates/:id → /login', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/templates/t1');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TemplateDetailPage), findsNothing);
  });

  testWidgets(
    'AuthAuthenticated → /templates/:templateId/bots/new monta BotCreatePage '
    'con templateId del path y templateName del query',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/templates/t1/bots/new?name=Soporte%20ventas');
      await tester.pumpAndSettle();

      final page = tester.widget<BotCreatePage>(find.byType(BotCreatePage));
      expect(page.templateId, 't1');
      expect(page.templateName, 'Soporte ventas');
    },
  );

  testWidgets(
    'AuthAuthenticated → /templates/:templateId/bots/new sin query name → '
    'BotCreatePage con templateName null (deep-link sin nombre)',
    (tester) async {
      // Permite la entrada deep-link directa por URL: el page muestra
      // el copy fallback en el chip en lugar de exponer el UUID.
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/templates/t1/bots/new');
      await tester.pumpAndSettle();

      final page = tester.widget<BotCreatePage>(find.byType(BotCreatePage));
      expect(page.templateId, 't1');
      expect(page.templateName, isNull);
    },
  );

  testWidgets(
    'AuthUnauthenticated + deep-link a /templates/:id/bots/new → /login',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
      router = AppRouter(
        authBloc: authBloc,
        authRepository: _MockAuthRepo(),
        botsRepository: botsRepo,
        botSessionRepository: botSessionRepo,
        conversationsRepository: conversationsRepo,
        messagesRepository: messagesRepo,
        templatesRepository: templatesRepo,
        flowsRepository: flowsRepo,
        triggersRepository: triggersRepo,
        waLabelsRepository: _MockWaLabelsRepo(),
        labelsRepository: labelsRepo,
        membershipsRepository: membershipsRepo,
        membersRepository: membersRepo,
        invitationsRepository: invitationsRepo,
        catalogRepository: catalogRepo,
        notificationsRepository: notificationsRepo,
        mediaRepository: _MockMediaRepo(),
        mediaFilePicker: _FakeMediaFilePicker(),
        mediaThumbnailLoader: const FakeThumbnailLoader(),
        profileRepository: profileRepo,
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/templates/t1/bots/new?name=X');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(BotCreatePage), findsNothing);
    },
  );

  testWidgets('AuthAuthenticated → /bots/new monta BotTemplatePickerPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/new');
    await tester.pumpAndSettle();

    expect(find.byType(BotTemplatePickerPage), findsOneWidget);
  });

  testWidgets(
    'AuthAuthenticated → /bots/new expone TemplatesBloc page-scoped y '
    'dispara TemplatesLoadRequested al construirse',
    (tester) async {
      // Bloc page-scoped (no reusa el del shell): si lo movieran a un
      // ámbito superior, el test del bloc sigue verde pero el contador
      // de list() en `setUp` se mantiene en una sola llamada -- aquí
      // exigimos una llamada adicional disparada por el route builder.
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      // Tras /home el repo ya recibió una llamada (TemplatesBloc del shell).
      // Limpiamos para verificar exactamente la llamada del picker.
      clearInteractions(templatesRepo);
      router.router.go('/bots/new');
      await tester.pumpAndSettle();

      final picker = tester.element(find.byType(BotTemplatePickerPage));
      expect(picker.read<TemplatesBloc>(), isNotNull);
      verify(templatesRepo.list).called(1);
    },
  );

  testWidgets('AuthUnauthenticated + deep-link a /bots/new → /login', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/new');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(BotTemplatePickerPage), findsNothing);
  });

  testWidgets(
    'AuthAuthenticated → /memberships monta MembershipsPage y dispara '
    'MembershipsLoadRequested al construirse',
    (tester) async {
      // El bloc page-scoped vive en el route builder de /memberships; el
      // verify garantiza que el load arranca solo, sin que la página tenga
      // que conocer el ciclo de vida (igual que TemplateDetail/BotDetail).
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/memberships');
      await tester.pumpAndSettle();

      expect(find.byType(MembershipsPage), findsOneWidget);
      verify(membershipsRepo.list).called(1);
    },
  );

  testWidgets('AuthAuthenticated → /members monta MembersPage y dispara '
      'MembersLoadRequested al construirse', (tester) async {
    // El bloc page-scoped vive en el route builder de /members; el verify
    // garantiza que el load arranca solo, sin que la página conozca el ciclo
    // de vida (igual que /memberships).
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/members');
    await tester.pumpAndSettle();

    expect(find.byType(MembersPage), findsOneWidget);
    verify(membersRepo.list).called(1);
  });

  testWidgets('AuthAuthenticated → /members expone MemberMutationCubit al árbol '
      '(habilita cambiar rol / quitar)', (tester) async {
    // Las mutaciones de la página necesitan el MemberMutationCubit page-scoped
    // en el route builder; sin él la página rompería en runtime (el
    // BlocListener lanzaría ProviderNotFound). Leerlo del árbol lo garantiza.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/members');
    await tester.pumpAndSettle();

    final page = tester.element(find.byType(MembersPage));
    expect(page.read<MemberMutationCubit>(), isNotNull);
  });

  testWidgets('AuthAuthenticated → /members/:id/bots monta BotAssignmentPage y '
      'carga (bots de la org + asignados)', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    when(
      () => membersRepo.assignedBots(any()),
    ).thenAnswer((_) async => const <String>[]);

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/members/m1/bots');
    await tester.pumpAndSettle();

    expect(find.byType(BotAssignmentPage), findsOneWidget);
    verify(() => membersRepo.assignedBots('m1')).called(1);
  });

  testWidgets('AuthAuthenticated → /invitations monta InvitationsPage y '
      'expone el InvitationMutationCubit + dispara el load', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/invitations');
    await tester.pumpAndSettle();

    expect(find.byType(InvitationsPage), findsOneWidget);
    verify(invitationsRepo.list).called(1);
    final page = tester.element(find.byType(InvitationsPage));
    expect(page.read<InvitationMutationCubit>(), isNotNull);
  });

  testWidgets('AuthAuthenticated → /members ofrece "Invitar" que navega a '
      '/invitations', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/members');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('members.invite')));
    await tester.pumpAndSettle();

    expect(find.byType(InvitationsPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /create-org monta CreateOrgPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/create-org');
    await tester.pumpAndSettle();

    expect(find.byType(CreateOrgPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticatedNoOrg → /create-org es alcanzable (allowlist: '
      'un usuario sin org debe poder crear la primera)', (tester) async {
    // Sin este allowlist el redirect rebotaría /create-org a /select-org y el
    // sin-org no tendría forma de crear su primera organización.
    when(() => authBloc.state).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/create-org');
    await tester.pumpAndSettle();

    expect(find.byType(CreateOrgPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticatedNoOrg → /select-org ofrece "Crear '
      'organización" que navega a /create-org', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Crear organización'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateOrgPage), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /memberships expone SwitchOrgCubit al árbol '
      '(habilita el switch in-app)', (tester) async {
    // El switch desde /memberships necesita el SwitchOrgCubit page-scoped en
    // el route builder; sin él la página rompería en runtime (ProviderNotFound
    // del BlocListener). Leerlo desde el árbol de la página lo garantiza —
    // ningún widget test aislado (que inyecta el cubit) cubre este seam.
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/memberships');
    await tester.pumpAndSettle();

    final page = tester.element(find.byType(MembershipsPage));
    expect(page.read<SwitchOrgCubit>(), isNotNull);
  });

  testWidgets('AuthAuthenticated → /memberships expone RenameOrgCubit al árbol '
      '(habilita renombrar la org activa)', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/memberships');
    await tester.pumpAndSettle();

    final page = tester.element(find.byType(MembershipsPage));
    expect(page.read<RenameOrgCubit>(), isNotNull);
  });

  testWidgets(
    'AuthAuthenticatedNoOrg → /select-org monta SelectOrgPage (no el placeholder) '
    'y dispara MembershipsLoadRequested',
    (tester) async {
      // Sin org activa el redirect manda todo a /select-org; la ruta debe
      // montar la página real (lista + switch), no el placeholder de solo
      // "Cerrar sesión". El verify garantiza que el MembershipsBloc page-scoped
      // arranca el load solo al construirse.
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();

      expect(find.byType(SelectOrgPage), findsOneWidget);
      verify(membershipsRepo.list).called(1);
    },
  );

  testWidgets(
    'desde /select-org vacío, "Aceptar una invitación" navega a /accept-invite '
    '(la única puerta del invitado sin org propia)',
    (tester) async {
      // El invitado logueado sin membership aterriza en el estado vacío de
      // /select-org; sin esta puerta quedaría varado. El botón empuja la ruta
      // de aceptación de invitación contra el router real.
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));
      when(membershipsRepo.list).thenAnswer((_) async => const <Membership>[]);

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(SelectOrgPage), findsOneWidget);

      await tester.tap(find.text('Aceptar una invitación'));
      await tester.pumpAndSettle();

      expect(find.byType(AcceptInvitePage), findsOneWidget);
    },
  );

  testWidgets(
    'AuthAuthenticated → /notifications monta NotificationsPage y carga inbox',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/notifications');
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
      verify(() => notificationsRepo.listInbox(unreadOnly: true)).called(1);
    },
  );

  testWidgets(
    'AuthAuthenticated → /notification-preferences monta preferencias y carga',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/notification-preferences');
      await tester.pumpAndSettle();

      expect(find.byType(NotificationPreferencesPage), findsOneWidget);
      verify(notificationsRepo.listPreferences).called(1);
    },
  );

  testWidgets(
    'AuthAuthenticated → /templates/:id/edit monta TemplateEditPage y carga',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
      when(() => templatesRepo.byId('t1')).thenAnswer(
        (_) async => const Template(
          id: 't1',
          orgId: 'o1',
          name: 'Soporte',
          version: 1,
          ai: AIConfig(
            enabled: false,
            provider: AIProvider.gemini,
            model: 'gemini-3.1-pro-preview',
            temperature: 0.7,
            thinkingLevel: ThinkingLevel.low,
            systemPrompt: '',
            contextMessages: 20,
          ),
        ),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      // /templates/:id/edit DEBE declararse antes que /templates/:id en
      // el router para que `:id` no capture "new" o "edit" como id
      // literal (mismo orden contractual que /templates/new).
      router.router.go('/templates/t1/edit');
      await tester.pumpAndSettle();

      expect(find.byType(TemplateEditPage), findsOneWidget);
      verify(() => templatesRepo.byId('t1')).called(1);
    },
  );

  testWidgets(
    'AuthUnauthenticated + deep-link a /templates/:id/edit → /login',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
      router = AppRouter(
        authBloc: authBloc,
        authRepository: _MockAuthRepo(),
        botsRepository: botsRepo,
        botSessionRepository: botSessionRepo,
        conversationsRepository: conversationsRepo,
        messagesRepository: messagesRepo,
        templatesRepository: templatesRepo,
        flowsRepository: flowsRepo,
        triggersRepository: triggersRepo,
        waLabelsRepository: _MockWaLabelsRepo(),
        labelsRepository: labelsRepo,
        membershipsRepository: membershipsRepo,
        membersRepository: membersRepo,
        invitationsRepository: invitationsRepo,
        catalogRepository: catalogRepo,
        notificationsRepository: notificationsRepo,
        mediaRepository: _MockMediaRepo(),
        mediaFilePicker: _FakeMediaFilePicker(),
        mediaThumbnailLoader: const FakeThumbnailLoader(),
        profileRepository: profileRepo,
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/templates/t1/edit');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(TemplateEditPage), findsNothing);
    },
  );

  testWidgets('AuthUnauthenticated + deep-link a /memberships → /login', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/memberships');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(MembershipsPage), findsNothing);
  });

  testWidgets('/register (ruta pública) renderiza RegisterPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/register');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('"Crear cuenta" desde el login navega a /register', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets(
    'deep-link directo a /register + "Ya tengo cuenta" cae al login sin '
    'reventar la pila',
    (tester) async {
      // Cold deep-link: /register es ruta pública, así que un usuario sin
      // sesión puede aterrizar ahí con la pila en un solo elemento. El back
      // no puede hacer pop (no hay a dónde) y debe ir a /login en su lugar.
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/register');
      await tester.pumpAndSettle();
      expect(find.byType(RegisterPage), findsOneWidget);

      await tester.tap(find.text('Ya tengo cuenta'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
    },
  );

  testWidgets(
    '/forgot-password (ruta pública) renderiza ForgotPasswordPage sin sesión',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/forgot-password');
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
    },
  );

  testWidgets(
    '/reset-password (ruta pública) renderiza ResetPasswordPage sin sesión',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/reset-password');
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsOneWidget);
    },
  );

  testWidgets(
    '/verify-email (ruta pública) renderiza VerifyEmailPage sin sesión',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/verify-email');
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailPage), findsOneWidget);
    },
  );

  testWidgets(
    '/verify-email se permite también con sesión (verificar logueado)',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/verify-email');
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailPage), findsOneWidget);
    },
  );

  testWidgets(
    '/accept-invite (ruta pública) renderiza AcceptInvitePage sin sesión',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/accept-invite');
      await tester.pumpAndSettle();

      expect(find.byType(AcceptInvitePage), findsOneWidget);
    },
  );

  testWidgets(
    '/accept-invite alcanzable con AuthAuthenticatedNoOrg (allowlist del '
    'redirect sin org activa)',
    (tester) async {
      when(
        () => authBloc.state,
      ).thenReturn(const AuthAuthenticatedNoOrg(_noOrg));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/accept-invite');
      await tester.pumpAndSettle();

      expect(find.byType(AcceptInvitePage), findsOneWidget);
    },
  );

  testWidgets(
    '/accept-invite se permite también con sesión activa (aceptar logueado)',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/accept-invite');
      await tester.pumpAndSettle();

      expect(find.byType(AcceptInvitePage), findsOneWidget);
    },
  );

  testWidgets(
    '"¿Olvidaste tu contraseña?" desde el login navega a /forgot-password',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
    },
  );

  testWidgets(
    '"Ya tengo un código" desde /forgot-password empuja /reset-password',
    (tester) async {
      when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      router.router.go('/forgot-password');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ya tengo un código'));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordPage), findsOneWidget);
    },
  );

  testWidgets('reset exitoso despacha AuthLoggedOut y aterriza en el login', (
    tester,
  ) async {
    // El canje revoca todas las familias de refresh en el backend: la ruta
    // debe cerrar la sesión local (AuthLoggedOut, idempotente si no hay
    // tokens) y rutear al login. El authRepo local se stubea para que el
    // resetPassword del bloc page-scoped resuelva en éxito (el _MockAuthRepo
    // inline del setUp no es alcanzable).
    final authRepo = _MockAuthRepo();
    when(
      () => authRepo.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    final localRouter = AppRouter(
      authBloc: authBloc,
      authRepository: authRepo,
      botsRepository: botsRepo,
      botSessionRepository: botSessionRepo,
      conversationsRepository: conversationsRepo,
      messagesRepository: messagesRepo,
      templatesRepository: templatesRepo,
      flowsRepository: flowsRepo,
      triggersRepository: triggersRepo,
      waLabelsRepository: _MockWaLabelsRepo(),
      labelsRepository: labelsRepo,
      membershipsRepository: membershipsRepo,
      membersRepository: membersRepo,
      invitationsRepository: invitationsRepo,
      catalogRepository: catalogRepo,
      notificationsRepository: notificationsRepo,
      mediaRepository: _MockMediaRepo(),
      mediaFilePicker: _FakeMediaFilePicker(),
      mediaThumbnailLoader: const FakeThumbnailLoader(),
      profileRepository: profileRepo,
    );

    await tester.pumpWidget(_host(localRouter, authBloc));
    await tester.pumpAndSettle();
    localRouter.router.go('/reset-password');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reset.token')), 'tok123');
    await tester.enterText(
      find.byKey(const Key('reset.password')),
      'hunter2-secret',
    );
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(const AuthLoggedOut())).called(1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ResetPasswordPage), findsNothing);
    // El login aterriza con el aviso de éxito (?reset=success): el operador
    // sabe que su contraseña cambió y que debe entrar con la nueva.
    expect(
      find.text('Contraseña restablecida. Inicia sesión con la nueva.'),
      findsOneWidget,
    );
  });
}
