import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_card.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

const _dm = Conversation(
  chatLid: 'lid-dm',
  kind: ConversationKind.dm,
  phone: '5215550001',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);
const _group = Conversation(
  chatLid: 'lid-grp',
  kind: ConversationKind.group,
  phone: null,
  isArchived: false,
  isPinned: true,
  isMarkedUnread: false,
  mutedUntil: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const ConversationsLoadRequested());
  });

  late _MockConversationsBloc bloc;

  setUp(() {
    bloc = _MockConversationsBloc();
    when(() => bloc.state).thenReturn(const ConversationsInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ConversationsBloc>.value(
      value: bloc,
      child: const Scaffold(body: ConversationsListPage()),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const ConversationsLoading());
    await tester.pumpWidget(host());
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
  });

  testWidgets(
    'Loaded con N conversaciones renderiza una AppCard por cada una',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm, _group],
          isRefreshing: false,
        ),
      );
      await tester.pumpWidget(host());

      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.byType(AppAvatar), findsNWidgets(2));
      // DM se identifica por phone (no hay nombre aún); GROUP por etiqueta.
      expect(find.text('5215550001'), findsOneWidget);
      expect(find.text('Grupo'), findsOneWidget);
    },
  );

  testWidgets('conversación fijada muestra AppPill "Fijado"', (tester) async {
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_group],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.widgetWithText(AppPill, 'Fijado'), findsOneWidget);
  });

  testWidgets('Loaded vacío muestra empty state (sin tiles)', (tester) async {
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(items: <Conversation>[], isRefreshing: false),
    );
    await tester.pumpWidget(host());
    expect(find.byType(AppCard), findsNothing);
    expect(find.byKey(const Key('conversations.empty')), findsOneWidget);
  });

  testWidgets('Failed genérico → mensaje genérico + Reintentar', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const ConversationsFailed(ConversationsNetworkFailure()));
    await tester.pumpWidget(host());
    expect(
      find.byKey(const Key('conversations.error.generic')),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
  });

  testWidgets('Failed NotFound → copy específico "este bot ya no existe"', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const ConversationsFailed(ConversationsNotFoundFailure()));
    await tester.pumpWidget(host());
    expect(
      find.byKey(const Key('conversations.error.not_found')),
      findsOneWidget,
    );
  });

  testWidgets('tap Reintentar dispara ConversationsLoadRequested', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const ConversationsFailed(ConversationsServerFailure()));
    await tester.pumpWidget(host());
    await tester.tap(find.widgetWithText(AppButton, 'Reintentar'));
    await tester.pump();
    verify(() => bloc.add(const ConversationsLoadRequested())).called(1);
  });

  group('bandeja enriquecida (nombre + último-mensaje + no-leídos)', () {
    Future<void> pumpOne(WidgetTester tester, Conversation c) async {
      when(() => bloc.state).thenReturn(
        ConversationsLoaded(items: <Conversation>[c], isRefreshing: false),
      );
      await tester.pumpWidget(host());
    }

    testWidgets('displayName se muestra como título (sobre phone)', (
      tester,
    ) async {
      await pumpOne(
        tester,
        const Conversation(
          chatLid: 'lid-dm',
          kind: ConversationKind.dm,
          phone: '5215550001',
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
          displayName: 'Alice',
        ),
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('5215550001'), findsNothing);
    });

    testWidgets('último-mensaje de texto: preview + hora', (tester) async {
      // Instante fijo; la hora esperada se calcula con la misma fórmula local
      // del widget para no depender de la zona horaria del runner.
      const ts = 1700000000000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final hhmm =
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
      await pumpOne(
        tester,
        const Conversation(
          chatLid: 'lid-dm',
          kind: ConversationKind.dm,
          phone: '5215550001',
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
          lastMessagePreview: 'nos vemos',
          lastMessageType: 'text',
          lastMessageDirection: 'INBOUND',
          lastMessageTimestampMs: ts,
        ),
      );
      expect(find.text('nos vemos'), findsOneWidget);
      expect(find.text(hhmm), findsOneWidget);
    });

    testWidgets(
      'último-mensaje no-texto: etiqueta de tipo en vez del preview',
      (tester) async {
        await pumpOne(
          tester,
          const Conversation(
            chatLid: 'lid-dm',
            kind: ConversationKind.dm,
            phone: '5215550001',
            isArchived: false,
            isPinned: false,
            isMarkedUnread: false,
            mutedUntil: null,
            lastMessagePreview: '',
            lastMessageType: 'image',
            lastMessageDirection: 'INBOUND',
            lastMessageTimestampMs: 1700000000000,
          ),
        );
        expect(find.text('Imagen'), findsOneWidget);
      },
    );

    testWidgets('no-leídos: badge verde con el conteo', (tester) async {
      await pumpOne(
        tester,
        const Conversation(
          chatLid: 'lid-dm',
          kind: ConversationKind.dm,
          phone: '5215550001',
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
          lastMessagePreview: 'hola',
          lastMessageType: 'text',
          lastMessageDirection: 'INBOUND',
          lastMessageTimestampMs: 1700000000000,
          unreadCount: 3,
        ),
      );
      final badge = find.byKey(const Key('conversation.unread.lid-dm'));
      expect(badge, findsOneWidget);
      expect(
        find.descendant(of: badge, matching: find.text('3')),
        findsOneWidget,
      );
      final box = tester.widget<Container>(badge);
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, AppTokens.chatAccent);
    });

    testWidgets('sin no-leídos (0) → sin badge', (tester) async {
      await pumpOne(
        tester,
        const Conversation(
          chatLid: 'lid-dm',
          kind: ConversationKind.dm,
          phone: '5215550001',
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
          lastMessagePreview: 'hola',
          lastMessageType: 'text',
          lastMessageDirection: 'INBOUND',
          lastMessageTimestampMs: 1700000000000,
        ),
      );
      expect(find.byKey(const Key('conversation.unread.lid-dm')), findsNothing);
    });
  });
}
