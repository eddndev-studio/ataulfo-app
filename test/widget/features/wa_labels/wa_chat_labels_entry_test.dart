import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:ataulfo/features/labels/domain/repositories/chat_labels_repository.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_mapping.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/noop_profile_photo_cache.dart';

class _MockConvBloc extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

class _MockWaRepo extends Mock implements WaLabelsRepository {}

class _MockChatLabelsRepo extends Mock implements ChatLabelsRepository {}

const _dm = Conversation(
  chatLid: 'lid-dm',
  kind: ConversationKind.dm,
  phone: '5215550001',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  displayName: 'Alice',
  unreadCount: 0,
  lastMessagePreview: null,
  lastMessageType: null,
  lastMessageDirection: null,
  lastMessageTimestampMs: null,
);

void main() {
  late _MockConvBloc conv;
  late _MockWaRepo repo;
  late _MockChatLabelsRepo chatLabelsRepo;

  setUp(() {
    conv = _MockConvBloc();
    repo = _MockWaRepo();
    chatLabelsRepo = _MockChatLabelsRepo();
    when(() => conv.botId).thenReturn('b1');
    when(() => conv.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_dm],
        isRefreshing: false,
      ),
    );
    when(() => repo.listCatalog(any())).thenAnswer((_) async => <WaLabel>[]);
    when(
      () => repo.listChatAssocs(any()),
    ).thenAnswer((_) async => <WaChatAssoc>[]);
    when(
      () => repo.listMappings(any()),
    ).thenAnswer((_) async => <WaLabelMapping>[]);
    when(
      () => repo.liveEvents(any()),
    ).thenAnswer((_) => const Stream<WaLabelLiveEvent>.empty());
    when(
      () => chatLabelsRepo.listForChat(any(), any()),
    ).thenAnswer((_) async => <Label>[]);
  });

  Widget app() {
    final router = GoRouter(
      initialLocation: '/conv',
      routes: <RouteBase>[
        GoRoute(
          path: '/conv',
          builder: (_, _) => MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<WaLabelsRepository>.value(value: repo),
              RepositoryProvider<ChatLabelsRepository>.value(
                value: chatLabelsRepo,
              ),
              RepositoryProvider<ProfilePhotoCache>.value(
                value: NoopProfilePhotoCache(),
              ),
            ],
            child: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ConversationsBloc>.value(value: conv),
                BlocProvider<InboxLabelsCubit>(
                  create: (_) =>
                      InboxLabelsCubit(repo: repo, botId: 'b1')..load(),
                ),
              ],
              child: const Scaffold(body: ConversationsListPage()),
            ),
          ),
        ),
        GoRoute(
          path: '/bots/:id/sessions/:chatLid',
          builder: (_, _) => const Scaffold(body: Text('HILO_SENTINEL')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppDesignTheme.dark(),
      routerConfig: router,
    );
  }

  testWidgets('tocar el icono de etiquetas abre el sheet y NO navega al hilo', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('conversation.labels.lid-dm')));
    await tester.pumpAndSettle();

    // El sheet se abrió...
    expect(find.text('Etiquetas de este chat'), findsOneWidget);
    // ...y NO se navegó al hilo (el tap lo absorbió el IconButton).
    expect(find.text('HILO_SENTINEL'), findsNothing);
  });

  testWidgets('tocar el cuerpo de la fila SÍ navega al hilo', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('HILO_SENTINEL'), findsOneWidget);
  });

  testWidgets(
    'abrir el sheet desde la bandeja siembra WhatsApp: no re-consulta '
    'catálogo ni asociaciones',
    (tester) async {
      // Catálogo no-vacío + una asociación a este chat: la bandeja los carga
      // una vez y el sheet debe reusarlos en vez de volver a pedirlos.
      when(() => repo.listCatalog('b1')).thenAnswer(
        (_) async => const <WaLabel>[
          WaLabel(waLabelId: 'w1', name: 'VIP', color: 3, deleted: false),
        ],
      );
      when(() => repo.listChatAssocs('b1')).thenAnswer(
        (_) async => const <WaChatAssoc>[
          WaChatAssoc(chatLid: 'lid-dm', waLabelId: 'w1', labeled: true),
        ],
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle(); // InboxLabelsCubit.load() resuelve aquí

      // La bandeja cargó el catálogo + asociaciones exactamente una vez. Verify
      // de mocktail consume estas interacciones: el verifyNever de abajo solo
      // mira lo que pase DESPUÉS de abrir el sheet.
      verify(() => repo.listCatalog('b1')).called(1);
      verify(() => repo.listChatAssocs('b1')).called(1);

      await tester.tap(find.byKey(const Key('conversation.labels.lid-dm')));
      await tester.pumpAndSettle();

      expect(find.text('Etiquetas de este chat'), findsOneWidget);
      // El sheet se sembró del caché: abrirlo no dispara ninguna consulta nueva
      // de catálogo ni de asociaciones.
      verifyNever(() => repo.listCatalog(any()));
      verifyNever(() => repo.listChatAssocs(any()));
    },
  );
}
