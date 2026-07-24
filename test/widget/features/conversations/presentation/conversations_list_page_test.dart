import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_page_container.dart';
import 'package:ataulfo/core/design/widgets/app_choice_chip.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_notice_banner.dart';
import 'package:ataulfo/core/design/widgets/app_search_field.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/domain/failures/bots_failure.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/conversations/presentation/widgets/inbox_conversation_row.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/failures/labels_failure.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/noop_profile_photo_cache.dart';

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

class _MockBotsBloc extends MockBloc<BotsEvent, BotsState>
    implements BotsBloc {}

class _MockLabelsBloc extends MockBloc<LabelsAdminEvent, LabelsAdminState>
    implements LabelsAdminBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockMessagesRepository extends Mock implements MessagesRepository {}

class _MockChatLabelsRepository extends Mock implements ChatLabelsRepository {}

const identity = Identity(
  userId: 'user-1',
  orgId: 'org-1',
  role: 'WORKER',
  email: 'maria@rivera.gt',
  emailVerified: true,
);

const bot = Bot(
  id: 'bot-1',
  orgId: 'org-1',
  templateId: 'assistant-1',
  name: 'Ventas Guatemala',
  channel: BotChannel.waUnofficial,
  identifier: '+502 2440 9012',
  version: 2,
  paused: false,
  aiDisabled: false,
);

const vip = Label(
  id: 'vip',
  name: 'Cliente VIP',
  color: '#C57B57',
  description: 'Atención prioritaria',
);

const conversation = Conversation(
  botId: 'bot-1',
  chatLid: 'lid-1',
  kind: ConversationKind.dm,
  phone: '+502 5555 9012',
  displayName: 'Comercial Rivera',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  unreadCount: 3,
  lastMessagePreview: '¿Me confirma la entrega?',
  lastMessageType: 'text',
  lastMessageDirection: 'INBOUND',
  lastMessageTimestampMs: 1770000000000,
  needsAttention: true,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas Guatemala',
  channelType: 'WA_UNOFFICIAL',
  channelIdentifier: '+502 2440 9012',
  labels: <ConversationLabel>[
    ConversationLabel(id: 'vip', name: 'Cliente VIP', color: '#C57B57'),
  ],
);

Conversation conversationAt(int index) => Conversation(
  botId: 'bot-1',
  chatLid: 'lid-$index',
  kind: ConversationKind.dm,
  phone: '+502 5555 ${9000 + index}',
  displayName: 'Contacto Rivera $index',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  lastMessagePreview: 'Seguimiento de conversación $index',
  lastMessageType: 'text',
  lastMessageDirection: 'INBOUND',
  lastMessageTimestampMs: 1770000000000 - index,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas Guatemala',
  channelType: 'WA_UNOFFICIAL',
  channelIdentifier: '+502 2440 9012',
);

void main() {
  late _MockConversationsBloc inbox;
  late _MockBotsBloc bots;
  late _MockLabelsBloc labels;
  late _MockAuthBloc auth;
  late _MockMessagesRepository messages;
  late _MockChatLabelsRepository chatLabels;

  setUpAll(() {
    registerFallbackValue(const ConversationsLoadRequested());
  });

  setUp(() {
    inbox = _MockConversationsBloc();
    bots = _MockBotsBloc();
    labels = _MockLabelsBloc();
    auth = _MockAuthBloc();
    messages = _MockMessagesRepository();
    chatLabels = _MockChatLabelsRepository();
    when(() => auth.state).thenReturn(const AuthAuthenticated(identity));
    when(
      () => bots.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[bot], isRefreshing: false));
    when(() => labels.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[vip], isRefreshing: false),
    );
  });

  Widget host(ConversationsState state) {
    when(() => inbox.state).thenReturn(state);
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<ProfilePhotoCache>.value(
          value: NoopProfilePhotoCache(),
        ),
        RepositoryProvider<MessagesRepository>.value(value: messages),
        RepositoryProvider<ChatLabelsRepository>.value(value: chatLabels),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<BotsBloc>.value(value: bots),
          BlocProvider<LabelsAdminBloc>.value(value: labels),
          BlocProvider<ConversationsBloc>.value(value: inbox),
        ],
        child: MaterialApp(
          theme: AppDesignTheme.dark(),
          home: const Scaffold(body: ConversationsListPage()),
        ),
      ),
    );
  }

  testWidgets('búsqueda y facetas comparten una jerarquía compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        const ConversationsState(
          phase: ConversationsPhase.ready,
          items: <Conversation>[conversation],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSearchField), findsOneWidget);
    final searchRect = tester.getRect(find.byKey(const Key('inbox.search')));
    expect(searchRect.left, AppPageGutters.primary);
    expect(searchRect.right, 430 - AppPageGutters.primary);
    final searchField = tester.widget<AppSearchField>(
      find.byKey(const Key('inbox.search')),
    );
    expect(searchField.hint, 'Buscar contacto, canal o asistente…');
    final searchY = tester.getTopLeft(find.byKey(const Key('inbox.search'))).dy;
    final statusY = tester
        .getTopLeft(find.byKey(const Key('inbox.status.filters')))
        .dy;
    final channelY = tester
        .getTopLeft(find.byKey(const Key('inbox.channel.filter')))
        .dy;
    final labelsY = tester
        .getTopLeft(find.byKey(const Key('inbox.labels.filters')))
        .dy;
    final rowY = tester
        .getTopLeft(find.byKey(const Key('conversation.tile.bot-1.lid-1')))
        .dy;
    expect(searchY, lessThan(statusY));
    expect(channelY, closeTo(statusY, 0.1));
    expect(labelsY, closeTo(statusY, 0.1));
    expect(statusY, lessThan(rowY));
    expect(find.text('Buscar conversaciones'), findsNothing);
    expect(find.text('Canal conectado'), findsNothing);
    expect(
      find.text('Una conexión concreta, no sólo el tipo de canal.'),
      findsNothing,
    );
    expect(find.text('Etiquetas internas'), findsNothing);
  });

  testWidgets(
    'un canal contextual ausente no rompe el selector mientras carga',
    (tester) async {
      when(
        () => bots.state,
      ).thenReturn(const BotsLoaded(items: <Bot>[], isRefreshing: false));

      await tester.pumpWidget(
        host(
          const ConversationsState(
            phase: ConversationsPhase.ready,
            query: InboxQuery(botId: 'bot-eliminado'),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Canal'), findsOneWidget);
    },
  );

  testWidgets(
    'no invalida filtros contextuales antes de cargar sus catálogos',
    (tester) async {
      when(() => bots.state).thenReturn(const BotsLoading());
      when(() => labels.state).thenReturn(const LabelsAdminLoading());

      await tester.pumpWidget(
        host(
          const ConversationsState(
            phase: ConversationsPhase.ready,
            query: InboxQuery(
              botId: 'bot-contextual',
              labelId: 'vip-contextual',
            ),
          ),
        ),
      );
      await tester.pump();

      verifyNever(
        () => inbox.add(any(that: isA<ConversationsValidChannelsChanged>())),
      );
      verifyNever(
        () => inbox.add(any(that: isA<ConversationsValidLabelsChanged>())),
      );
    },
  );

  testWidgets(
    'un refresh fallido conserva el último catálogo visible de filtros',
    (tester) async {
      final botStates = StreamController<BotsState>();
      final labelStates = StreamController<LabelsAdminState>();
      addTearDown(botStates.close);
      addTearDown(labelStates.close);
      whenListen(
        bots,
        botStates.stream,
        initialState: const BotsLoaded(items: <Bot>[bot], isRefreshing: false),
      );
      whenListen(
        labels,
        labelStates.stream,
        initialState: const LabelsAdminLoaded(
          labels: <Label>[vip],
          isRefreshing: false,
        ),
      );
      const state = ConversationsState(
        phase: ConversationsPhase.ready,
        query: InboxQuery(botId: 'bot-1', labelId: 'vip'),
        items: <Conversation>[conversation],
      );
      await tester.pumpWidget(host(state));
      await tester.pump();

      Finder channelFilterLabel() => find.descendant(
        of: find.byKey(const Key('inbox.channel.filter')),
        matching: find.text('Ventas Guatemala · +502 2440 9012'),
      );
      Finder labelFilterChip() => find.descendant(
        of: find.byKey(const Key('inbox.labels.filters')),
        matching: find.text('Cliente VIP'),
      );
      expect(channelFilterLabel(), findsOneWidget);
      expect(labelFilterChip(), findsOneWidget);

      botStates.add(const BotsFailed(BotsNetworkFailure()));
      labelStates.add(const LabelsAdminFailed(LabelsNetworkFailure()));
      await tester.pumpAndSettle();
      expect(bots.state, isA<BotsFailed>());
      expect(labels.state, isA<LabelsAdminFailed>());

      expect(channelFilterLabel(), findsOneWidget);
      expect(labelFilterChip(), findsOneWidget);
    },
  );

  testWidgets(
    'usa labels internas, muestra procedencia y no ofrece labels WA',
    (tester) async {
      await tester.pumpWidget(
        host(
          const ConversationsState(
            phase: ConversationsPhase.ready,
            items: <Conversation>[conversation],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cliente VIP'), findsOneWidget);
      expect(find.textContaining('Ventas regionales'), findsOneWidget);
      expect(find.textContaining('Ventas Guatemala'), findsWidgets);
      expect(
        find.byKey(const Key('conversation.labels.bot-1.lid-1')),
        findsNothing,
      );
      expect(find.textContaining('WhatsApp'), findsNothing);

      await tester.tap(find.byKey(const Key('inbox.labels.filters')));
      await tester.pumpAndSettle();
      expect(find.text('Cliente VIP'), findsNWidgets(2));
    },
  );

  testWidgets('canal, etiqueta y estado despachan facetas independientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const ConversationsState(phase: ConversationsPhase.ready)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('inbox.channel.filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox.channel.option.bot-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inbox.labels.filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox.label.option.vip')));
    await tester.pumpAndSettle();

    final filterScroll = find.descendant(
      of: find.byKey(const Key('inbox.filters')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(filterScroll, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppChoiceChip, 'Requieren atención'));

    final events = verify(
      () => inbox.add(captureAny()),
    ).captured.cast<ConversationsEvent>();
    expect(
      events.whereType<ConversationsStatusChanged>().single.status,
      InboxStatus.attention,
    );
    expect(
      events.whereType<ConversationsChannelChanged>().single.botId,
      'bot-1',
    );
    expect(events.whereType<ConversationsLabelChanged>().single.labelId, 'vip');
  });

  testWidgets('Todas las etiquetas limpia la faceta singular', (tester) async {
    await tester.pumpWidget(
      host(
        const ConversationsState(
          phase: ConversationsPhase.ready,
          query: InboxQuery(labelId: 'vip'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('inbox.labels.filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox.label.option.all')));
    await tester.pumpAndSettle();

    final events = verify(
      () => inbox.add(captureAny()),
    ).captured.cast<ConversationsEvent>();
    expect(
      events.whereType<ConversationsLabelChanged>().single.labelId,
      isNull,
    );
  });

  testWidgets(
    'offline con caché conserva filas y presenta aviso no bloqueante',
    (tester) async {
      await tester.pumpWidget(
        host(
          const ConversationsState(
            phase: ConversationsPhase.ready,
            items: <Conversation>[conversation],
            isOffline: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppNoticeBanner), findsOneWidget);
      expect(find.textContaining('sin conexión'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('conversation.tile.bot-1.lid-1')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('conversation.tile.bot-1.lid-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('abrir un hilo y volver conserva filtros, scroll e instancia', (
    tester,
  ) async {
    final items = List<Conversation>.generate(24, conversationAt);
    const query = InboxQuery(
      search: 'Rivera',
      status: InboxStatus.unread,
      botId: 'bot-1',
      labelId: 'vip',
    );
    when(() => inbox.state).thenReturn(
      ConversationsState(
        phase: ConversationsPhase.ready,
        query: query,
        items: items,
      ),
    );
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: ConversationsListPage()),
        ),
        GoRoute(
          path: '/bots/:id/sessions/:chatLid',
          builder: (_, state) => Scaffold(
            key: const Key('test.thread'),
            body: Text(state.pathParameters['chatLid']!),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          RepositoryProvider<ProfilePhotoCache>.value(
            value: NoopProfilePhotoCache(),
          ),
          RepositoryProvider<MessagesRepository>.value(value: messages),
          RepositoryProvider<ChatLabelsRepository>.value(value: chatLabels),
        ],
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<BotsBloc>.value(value: bots),
            BlocProvider<LabelsAdminBloc>.value(value: labels),
            BlocProvider<ConversationsBloc>.value(value: inbox),
          ],
          child: MaterialApp.router(
            theme: AppDesignTheme.dark(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageState = tester.state(find.byType(ConversationsListPage));
    var scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, -900));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;

    final target = find.byType(InboxConversationRow).hitTestable().last;
    final selectedKey = tester
        .widget<InboxConversationRow>(target)
        .conversation
        .stableKey;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test.thread')), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    expect(tester.state(find.byType(ConversationsListPage)), same(pageState));
    expect(inbox.state.query, query);
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(before, 0.1),
    );
    final selectedRow = tester
        .widgetList<InboxConversationRow>(find.byType(InboxConversationRow))
        .singleWhere((row) => row.conversation.stableKey == selectedKey);
    expect(selectedRow.selected, isTrue);
  });

  testWidgets('vacío filtrado se distingue del vacío inicial', (tester) async {
    await tester.pumpWidget(
      host(
        const ConversationsState(
          query: InboxQuery(search: 'sin coincidencias'),
          phase: ConversationsPhase.ready,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(
      find.text('No hay conversaciones con estos filtros'),
      findsOneWidget,
    );
  });

  testWidgets('loading usa skeleton de la lista y error usa componente DS', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const ConversationsState(phase: ConversationsPhase.loading)),
    );
    await tester.pump();
    expect(find.byKey(const Key('inbox.loading.skeleton')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      host(
        const ConversationsState(
          phase: ConversationsPhase.failure,
          failure: ConversationsServerFailure(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppErrorState), findsOneWidget);
  });
}
