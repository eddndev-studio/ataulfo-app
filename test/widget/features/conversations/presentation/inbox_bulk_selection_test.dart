import 'dart:async';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/auth/domain/entities/identity.dart';
import 'package:ataulfo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:ataulfo/features/bots/domain/entities/bot.dart';
import 'package:ataulfo/features/bots/presentation/bloc/bots_bloc.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/labels/presentation/bloc/labels_admin_bloc.dart';
import 'package:ataulfo/features/messages/domain/repositories/messages_repository.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

const worker = Identity(
  userId: 'worker-1',
  orgId: 'org-1',
  role: 'WORKER',
  email: 'worker@example.com',
  emailVerified: true,
);

const admin = Identity(
  userId: 'admin-1',
  orgId: 'org-1',
  role: 'ADMIN',
  email: 'admin@example.com',
  emailVerified: true,
);

const bot = Bot(
  id: 'bot-1',
  orgId: 'org-1',
  templateId: 'assistant-1',
  name: 'Ventas',
  channel: BotChannel.waUnofficial,
  identifier: '+502 2000 0000',
  version: 1,
  paused: false,
  aiDisabled: false,
);

const vip = Label(
  id: 'vip',
  name: 'Cliente VIP',
  color: '#C57B57',
  description: 'Atención prioritaria',
);

Conversation conversation(int index) => Conversation(
  botId: 'bot-1',
  chatLid: 'lid-$index',
  kind: ConversationKind.dm,
  phone: '+502 5555 $index',
  displayName: 'Contacto $index',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  unreadCount: index,
  lastMessagePreview: 'Mensaje $index',
  lastMessageType: 'text',
  lastMessageDirection: 'INBOUND',
  lastMessageTimestampMs: 1770000000000 - index,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas',
  channelType: 'WA_UNOFFICIAL',
);

void main() {
  late _MockConversationsBloc inbox;
  late _MockBotsBloc bots;
  late _MockLabelsBloc labels;
  late _MockAuthBloc auth;
  late _MockMessagesRepository messages;
  late _MockChatLabelsRepository chatLabels;

  final ready = ConversationsState(
    phase: ConversationsPhase.ready,
    items: <Conversation>[conversation(1), conversation(2)],
  );

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
    when(() => inbox.state).thenReturn(ready);
    when(() => auth.state).thenReturn(const AuthAuthenticated(worker));
    when(
      () => bots.state,
    ).thenReturn(const BotsLoaded(items: <Bot>[bot], isRefreshing: false));
    when(() => labels.state).thenReturn(
      const LabelsAdminLoaded(labels: <Label>[vip], isRefreshing: false),
    );
  });

  Widget host() => MultiRepositoryProvider(
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

  Future<void> selectFirst(WidgetTester tester) async {
    await tester.longPress(
      find.byKey(const Key('conversation.tile.bot-1.lid-1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'long press móvil abre selección y el tap siguiente alterna fila',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byKey(const Key('inbox.selection.bar')), findsNothing);
      await selectFirst(tester);
      expect(find.byKey(const Key('inbox.selection.bar')), findsOneWidget);
      expect(find.text('1 seleccionada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('conversation.tile.bot-1.lid-2')));
      await tester.pump();
      expect(find.text('2 seleccionadas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbox.selection.cancel')));
      await tester.pump();
      expect(find.byKey(const Key('inbox.selection.bar')), findsNothing);
    },
  );

  testWidgets('escritorio ofrece casilla explícita y operable', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.pump();

    final checkbox = find.byKey(const Key('conversation.select.bot-1.lid-1'));
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pump();
    expect(find.text('1 seleccionada'), findsOneWidget);
  });

  testWidgets(
    'éxito parcial muestra N de M, retiene fallo y refresca una vez',
    (tester) async {
      when(() => messages.markRead('bot-1', 'lid-1')).thenAnswer((_) async {});
      when(
        () => messages.markRead('bot-1', 'lid-2'),
      ).thenThrow(Exception('sin red'));
      await tester.pumpWidget(host());
      await tester.pump();
      await selectFirst(tester);
      await tester.tap(find.byKey(const Key('conversation.tile.bot-1.lid-2')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('inbox.selection.mark_read')));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 de 2'), findsOneWidget);
      expect(find.text('1 seleccionada'), findsOneWidget);
      verify(() => inbox.add(const ConversationsRefreshRequested())).called(1);
    },
  );

  testWidgets('etiquetar agrega la etiqueta interna y refresca una vez', (
    tester,
  ) async {
    when(
      () => chatLabels.addToChat('bot-1', 'lid-1', 'vip'),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(host());
    await tester.pump();
    await selectFirst(tester);

    await tester.tap(find.byKey(const Key('inbox.selection.labels')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox.labels.action_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('inbox.labels.label.vip')));
    await tester.pumpAndSettle();

    verify(() => chatLabels.addToChat('bot-1', 'lid-1', 'vip')).called(1);
    verify(() => inbox.add(const ConversationsRefreshRequested())).called(1);
  });

  testWidgets('cambiar búsqueda o filtros limpia la selección', (tester) async {
    final states = StreamController<ConversationsState>.broadcast();
    addTearDown(states.close);
    whenListen(inbox, states.stream, initialState: ready);
    await tester.pumpWidget(host());
    await tester.pump();
    await selectFirst(tester);

    states.add(
      ready.copyWith(query: const InboxQuery(search: 'otra búsqueda')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inbox.selection.bar')), findsNothing);
  });

  testWidgets('WORKER no ve Vaciar historial', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await selectFirst(tester);

    expect(
      find.byKey(const Key('inbox.selection.clear_history')),
      findsNothing,
    );
  });

  testWidgets(
    'ADMIN confirma copy preciso antes de vaciar sin borrar la sesión',
    (tester) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(admin));
      when(
        () => messages.clearHistory('bot-1', 'lid-1'),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(host());
      await tester.pump();
      await selectFirst(tester);

      await tester.tap(find.byKey(const Key('inbox.selection.clear_history')));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Vaciar el historial de 1 conversación?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Se eliminarán permanentemente los mensajes de 1 conversación. '
          'Se conservarán el contacto, la sesión y sus etiquetas. Esta acción '
          'no se puede deshacer.',
        ),
        findsOneWidget,
      );
      verifyNever(() => messages.clearHistory(any(), any()));

      await tester.tap(find.byKey(const Key('inbox.clear_history.confirm')));
      await tester.pumpAndSettle();
      verify(() => messages.clearHistory('bot-1', 'lid-1')).called(1);
    },
  );
}
