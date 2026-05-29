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
}
