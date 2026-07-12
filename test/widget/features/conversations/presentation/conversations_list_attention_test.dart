import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_attention_cubit.dart';
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

class _MockInboxLabelsCubit extends MockCubit<InboxLabelsState>
    implements InboxLabelsCubit {}

class _MockAttentionCubit extends MockCubit<MonitorAttentionState>
    implements MonitorAttentionCubit {}

const _dm = Conversation(
  chatLid: 'lid-dm',
  kind: ConversationKind.dm,
  phone: '5215550001',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
);

/// Cableado real de la pill «Atención» en la fila de la bandeja: abrir un chat
/// lo atiende (clear) y lo suprime mientras su hilo está en foco (la bandeja
/// sigue montada bajo el push); volver (pop) reanuda la acumulación.
void main() {
  late _MockConversationsBloc bloc;
  late _MockInboxLabelsCubit inbox;
  late _MockAttentionCubit attention;
  late GoRouter router;

  setUp(() {
    bloc = _MockConversationsBloc();
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_dm],
        isRefreshing: false,
      ),
    );
    when(() => bloc.botId).thenReturn('b1');
    inbox = _MockInboxLabelsCubit();
    when(() => inbox.state).thenReturn(const InboxLabelsState());
    attention = _MockAttentionCubit();
    when(() => attention.state).thenReturn(const MonitorAttentionState());
    // Router real: el onTap de la fila hace context.push y espera el pop del
    // hilo, como en la app (la ruta del hilo es un placeholder).
    router = GoRouter(
      initialLocation: '/bots/b1/sessions',
      routes: <GoRoute>[
        GoRoute(
          path: '/bots/:id/sessions',
          builder: (_, _) => RepositoryProvider<ProfilePhotoCache>.value(
            value: NoopProfilePhotoCache(),
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ConversationsBloc>.value(value: bloc),
                BlocProvider<InboxLabelsCubit>.value(value: inbox),
                BlocProvider<MonitorAttentionCubit>.value(value: attention),
              ],
              child: const Scaffold(body: ConversationsListPage()),
            ),
          ),
        ),
        GoRoute(
          path: '/bots/:id/sessions/:chatLid',
          builder: (_, _) =>
              const Scaffold(body: Text('hilo', key: Key('thread.stub'))),
        ),
      ],
    );
  });

  testWidgets('abrir un chat ⇒ clear+suppress; volver (pop) ⇒ unsuppress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: AppDesignTheme.dark(), routerConfig: router),
    );

    await tester.tap(find.byKey(const Key('conversation.tile.lid-dm')));
    await tester.pumpAndSettle();

    // Navegó al hilo y atendió/suprimió la señal del chat; la supresión sigue
    // activa mientras el hilo está en foco.
    expect(find.byKey(const Key('thread.stub')), findsOneWidget);
    verify(() => attention.clear('lid-dm')).called(1);
    verify(() => attention.suppress('lid-dm')).called(1);
    verifyNever(() => attention.unsuppress());

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation.tile.lid-dm')), findsOneWidget);
    verify(() => attention.unsuppress()).called(1);
  });
}
