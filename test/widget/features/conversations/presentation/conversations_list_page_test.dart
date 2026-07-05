import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/tokens.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/core/design/widgets/app_button.dart';
import 'package:ataulfo/core/design/widgets/app_empty_state.dart';
import 'package:ataulfo/core/design/widgets/app_error_state.dart';
import 'package:ataulfo/core/design/widgets/app_loading_indicator.dart';
import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:ataulfo/features/conversations/presentation/cubit/inbox_labels_cubit.dart';
import 'package:ataulfo/features/conversations/presentation/pages/conversations_list_page.dart';
import 'package:ataulfo/features/profile/data/cache/profile_photo_cache.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_chat_assoc.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label.dart';
import 'package:ataulfo/features/wa_labels/domain/repositories/wa_labels_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/noop_profile_photo_cache.dart';

class _MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

class _MockInboxLabelsCubit extends MockCubit<InboxLabelsState>
    implements InboxLabelsCubit {}

class _MockWaLabelsRepo extends Mock implements WaLabelsRepository {}

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
  late _MockInboxLabelsCubit inbox;

  setUp(() {
    bloc = _MockConversationsBloc();
    when(() => bloc.state).thenReturn(const ConversationsInitial());
    // El avatar de cada fila lee `botId` en build (resuelve la foto del chat);
    // sin stub, el getter del mock devuelve null y revienta el tile.
    when(() => bloc.botId).thenReturn('b1');
    // Por defecto sin etiquetas: la bandeja se prueba sin blobs ni chips de
    // etiqueta salvo cuando un test los siembra explícitamente.
    inbox = _MockInboxLabelsCubit();
    when(() => inbox.state).thenReturn(const InboxLabelsState());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: RepositoryProvider<ProfilePhotoCache>.value(
      value: NoopProfilePhotoCache(),
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ConversationsBloc>.value(value: bloc),
          BlocProvider<InboxLabelsCubit>.value(value: inbox),
        ],
        child: const Scaffold(body: ConversationsListPage()),
      ),
    ),
  );

  testWidgets('Loading muestra spinner con AppTokens.primary', (tester) async {
    when(() => bloc.state).thenReturn(const ConversationsLoading());
    await tester.pumpWidget(host());
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor?.value, AppTokens.primary);
    // El spinner de página es el primitivo canónico del kit.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('Loaded con N conversaciones renderiza una fila por cada una', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_dm, _group],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('conversation.tile.lid-dm')), findsOneWidget);
    expect(find.byKey(const Key('conversation.tile.lid-grp')), findsOneWidget);
    expect(find.byType(AppAvatar), findsNWidgets(2));
    // DM se identifica por phone (no hay nombre aún); GROUP por etiqueta.
    expect(find.text('5215550001'), findsOneWidget);
    expect(find.text('Grupo'), findsOneWidget);
  });

  testWidgets('un chat con señal de atención muestra la píldora "Atención"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_dm, _group],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: RepositoryProvider<ProfilePhotoCache>.value(
          value: NoopProfilePhotoCache(),
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ConversationsBloc>.value(value: bloc),
              BlocProvider<InboxLabelsCubit>.value(value: inbox),
            ],
            child: const Scaffold(
              body: ConversationsListPage(needsAttention: <String>{'lid-dm'}),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('conversation.attention.lid-dm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation.attention.lid-grp')),
      findsNothing,
    );
  });

  testWidgets('cada conversación expone la acción de etiquetas de WhatsApp', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ConversationsLoaded(
        items: <Conversation>[_dm, _group],
        isRefreshing: false,
      ),
    );
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('conversation.labels.lid-dm')), findsOneWidget);
    expect(
      find.byKey(const Key('conversation.labels.lid-grp')),
      findsOneWidget,
    );
  });

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
    expect(find.byType(AppAvatar), findsNothing);
    expect(find.byKey(const Key('conversations.empty')), findsOneWidget);
    // El vacío rico canónico del kit, en su variante informativa (sin CTA).
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
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
    // La card de error es el primitivo canónico del kit.
    expect(find.byType(AppErrorState), findsOneWidget);
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

    testWidgets('grupo sin mensajes: nunca muestra el chatLid crudo', (
      tester,
    ) async {
      await pumpOne(
        tester,
        const Conversation(
          chatLid: '123456789-1234@g.us',
          kind: ConversationKind.group,
          phone: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      );
      // El JID no significa nada para el operador; el hueco se comunica
      // con copy humano.
      expect(find.text('123456789-1234@g.us'), findsNothing);
      expect(find.text('Sin mensajes'), findsOneWidget);
    });

    testWidgets('último-mensaje de texto: preview + hora', (tester) async {
      // Instante fijo de un año pasado; lo esperado se calcula con la misma
      // fórmula local del widget para no depender de la zona del runner. Al
      // ser de otro año, el timestamp inteligente antepone la fecha completa
      // (DD/MM/YY) — sin ella "14:32" no dice nada de cuándo fue.
      const ts = 1700000000000;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final dd = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final yy = (dt.year % 100).toString().padLeft(2, '0');
      final hhmm =
          '$dd/$mo/$yy '
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

  group('blobs de etiquetas WhatsApp por chat', () {
    const vip = WaLabel(waLabelId: 'A', name: 'VIP', color: 0, deleted: false);

    testWidgets('un chat con etiquetas muestra un blob por cada una', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm],
          isRefreshing: false,
        ),
      );
      when(() => inbox.state).thenReturn(
        const InboxLabelsState(
          catalog: <WaLabel>[vip],
          byChat: <String, List<WaLabel>>{
            'lid-dm': <WaLabel>[vip],
          },
        ),
      );
      await tester.pumpWidget(host());

      // Scoped al tile: el blob, no un chip de filtro homónimo.
      expect(
        find.descendant(
          of: find.byKey(const Key('conversation.tile.lid-dm')),
          matching: find.text('VIP'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un chat sin etiquetas no muestra blobs en su fila', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm],
          isRefreshing: false,
        ),
      );
      when(() => inbox.state).thenReturn(const InboxLabelsState());
      await tester.pumpWidget(host());

      expect(
        find.descendant(
          of: find.byKey(const Key('conversation.tile.lid-dm')),
          matching: find.text('VIP'),
        ),
        findsNothing,
      );
    });

    testWidgets('el texto del blob se aclara para etiquetas oscuras', (
      tester,
    ) async {
      // Índice 9 (índigo) es un swatch oscuro: el blob sube la luminancia del
      // texto para que siga legible sobre el tinte oscuro.
      const indigo = WaLabel(
        waLabelId: 'A',
        name: 'Índigo',
        color: 9,
        deleted: false,
      );
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm],
          isRefreshing: false,
        ),
      );
      when(() => inbox.state).thenReturn(
        const InboxLabelsState(
          catalog: <WaLabel>[indigo],
          byChat: <String, List<WaLabel>>{
            'lid-dm': <WaLabel>[indigo],
          },
        ),
      );
      await tester.pumpWidget(host());

      final blob = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('conversation.tile.lid-dm')),
          matching: find.text('Índigo'),
        ),
      );
      expect(
        HSLColor.fromColor(blob.style!.color!).lightness,
        greaterThanOrEqualTo(0.7),
      );
    });
  });

  group('filtros por etiqueta WhatsApp', () {
    const vip = WaLabel(waLabelId: 'A', name: 'VIP', color: 0, deleted: false);
    const soporte = WaLabel(
      waLabelId: 'B',
      name: 'Soporte',
      color: 3,
      deleted: false,
    );

    Conversation conv({required String chatLid, required String displayName}) =>
        Conversation(
          chatLid: chatLid,
          kind: ConversationKind.dm,
          phone: '521555',
          displayName: displayName,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
          lastMessagePreview: 'hola',
          lastMessageType: 'text',
          lastMessageDirection: 'INBOUND',
          lastMessageTimestampMs: 1700000000000,
        );

    testWidgets('los chips de filtro se generan desde el catálogo', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm],
          isRefreshing: false,
        ),
      );
      when(
        () => inbox.state,
      ).thenReturn(const InboxLabelsState(catalog: <WaLabel>[vip, soporte]));
      await tester.pumpWidget(host());
      expect(
        find.byKey(const Key('conversations.filter.label.A')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('conversations.filter.label.B')),
        findsOneWidget,
      );
    });

    testWidgets('sin catálogo no hay chips de etiqueta', (tester) async {
      when(() => bloc.state).thenReturn(
        const ConversationsLoaded(
          items: <Conversation>[_dm],
          isRefreshing: false,
        ),
      );
      when(() => inbox.state).thenReturn(const InboxLabelsState());
      await tester.pumpWidget(host());
      expect(
        find.byKey(const Key('conversations.filter.label.A')),
        findsNothing,
      );
    });

    testWidgets(
      'tocar un chip de etiqueta filtra a los chats con esa etiqueta',
      (tester) async {
        when(() => bloc.state).thenReturn(
          ConversationsLoaded(
            items: <Conversation>[
              conv(chatLid: 'l1', displayName: 'Con VIP'),
              conv(chatLid: 'l2', displayName: 'Sin etiqueta'),
            ],
            isRefreshing: false,
          ),
        );
        when(() => inbox.state).thenReturn(
          const InboxLabelsState(
            catalog: <WaLabel>[vip],
            byChat: <String, List<WaLabel>>{
              'l1': <WaLabel>[vip],
            },
          ),
        );
        await tester.pumpWidget(host());

        expect(find.text('Con VIP'), findsOneWidget);
        expect(find.text('Sin etiqueta'), findsOneWidget);

        await tester.tap(find.byKey(const Key('conversations.filter.label.A')));
        await tester.pump();

        expect(find.text('Con VIP'), findsOneWidget);
        expect(find.text('Sin etiqueta'), findsNothing);
      },
    );

    testWidgets('re-tocar el chip activo lo deselecciona (vuelve a Todas)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ConversationsLoaded(
          items: <Conversation>[
            conv(chatLid: 'l1', displayName: 'Con VIP'),
            conv(chatLid: 'l2', displayName: 'Sin etiqueta'),
          ],
          isRefreshing: false,
        ),
      );
      when(() => inbox.state).thenReturn(
        const InboxLabelsState(
          catalog: <WaLabel>[vip],
          byChat: <String, List<WaLabel>>{
            'l1': <WaLabel>[vip],
          },
        ),
      );
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('conversations.filter.label.A')));
      await tester.pump();
      expect(find.text('Sin etiqueta'), findsNothing);

      await tester.tap(find.byKey(const Key('conversations.filter.label.A')));
      await tester.pump();
      expect(find.text('Sin etiqueta'), findsOneWidget);
    });

    testWidgets(
      'si la etiqueta activa desaparece del catálogo, vuelve a mostrar todo',
      (tester) async {
        // Cubit real para poder recargar y emitir un catálogo sin la etiqueta.
        final repo = _MockWaLabelsRepo();
        when(
          () => repo.listCatalog('b1'),
        ).thenAnswer((_) async => const <WaLabel>[vip]);
        when(() => repo.listChatAssocs('b1')).thenAnswer(
          (_) async => const <WaChatAssoc>[
            WaChatAssoc(chatLid: 'l1', waLabelId: 'A', labeled: true),
          ],
        );
        final realCubit = InboxLabelsCubit(repo: repo, botId: 'b1');
        addTearDown(realCubit.close);
        await realCubit.load();

        when(() => bloc.state).thenReturn(
          ConversationsLoaded(
            items: <Conversation>[
              conv(chatLid: 'l1', displayName: 'Con VIP'),
              conv(chatLid: 'l2', displayName: 'Sin etiqueta'),
            ],
            isRefreshing: false,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppDesignTheme.dark(),
            home: RepositoryProvider<ProfilePhotoCache>.value(
              value: NoopProfilePhotoCache(),
              child: MultiBlocProvider(
                providers: <BlocProvider<dynamic>>[
                  BlocProvider<ConversationsBloc>.value(value: bloc),
                  BlocProvider<InboxLabelsCubit>.value(value: realCubit),
                ],
                child: const Scaffold(body: ConversationsListPage()),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('conversations.filter.label.A')));
        await tester.pump();
        // Filtrado por A: solo el chat con la etiqueta.
        expect(find.text('Sin etiqueta'), findsNothing);

        // A desaparece del catálogo (borrada o WhatsApp cae) en la recarga.
        when(
          () => repo.listCatalog('b1'),
        ).thenAnswer((_) async => const <WaLabel>[]);
        when(
          () => repo.listChatAssocs('b1'),
        ).thenAnswer((_) async => const <WaChatAssoc>[]);
        await realCubit.load();
        await tester.pump();

        // Reconciliado: el filtro colgado se ignora y la bandeja vuelve a todo.
        expect(find.text('Sin etiqueta'), findsOneWidget);
        expect(find.text('Con VIP'), findsOneWidget);
      },
    );
  });

  group('bandeja: búsqueda, filtros y jerarquía', () {
    Conversation conv({
      required String chatLid,
      String? displayName,
      String? phone,
      bool archived = false,
      bool pinned = false,
      int unread = 0,
      String lastType = 'text',
      String lastPreview = 'hola',
    }) => Conversation(
      chatLid: chatLid,
      kind: ConversationKind.dm,
      phone: phone ?? '5215550001',
      displayName: displayName,
      isArchived: archived,
      isPinned: pinned,
      isMarkedUnread: false,
      mutedUntil: null,
      unreadCount: unread,
      lastMessagePreview: lastPreview,
      lastMessageType: lastType,
      lastMessageDirection: 'INBOUND',
      lastMessageTimestampMs: 1700000000000,
    );

    void seed(List<Conversation> items) {
      when(
        () => bloc.state,
      ).thenReturn(ConversationsLoaded(items: items, isRefreshing: false));
    }

    testWidgets('la búsqueda filtra por nombre (case-insensitive)', (
      tester,
    ) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', displayName: 'Carlos Pérez'),
        conv(chatLid: 'l2', displayName: 'María López'),
      ]);
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('conversations.search')),
        'marí',
      );
      await tester.pump();

      expect(find.text('María López'), findsOneWidget);
      expect(find.text('Carlos Pérez'), findsNothing);
    });

    testWidgets('la búsqueda también encuentra por teléfono', (tester) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', phone: '5215550001'),
        conv(chatLid: 'l2', phone: '5219998888'),
      ]);
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('conversations.search')),
        '9998',
      );
      await tester.pump();

      expect(find.text('5219998888'), findsOneWidget);
      expect(find.text('5215550001'), findsNothing);
    });

    testWidgets('el preview de media lleva ícono de tipo', (tester) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', lastType: 'image', lastPreview: ''),
      ]);
      await tester.pumpWidget(host());

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('Imagen'), findsOneWidget);
    });

    testWidgets('con no-leídos el preview se enfatiza (text1 + w600)', (
      tester,
    ) async {
      seed(<Conversation>[conv(chatLid: 'l1', unread: 3)]);
      await tester.pumpWidget(host());

      final preview = tester.widget<Text>(
        find.byKey(const Key('conversation.preview.l1')),
      );
      expect(preview.style?.color, AppTokens.text1);
      expect(preview.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('filtro "No leídas" muestra solo las pendientes', (
      tester,
    ) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', displayName: 'Leída'),
        conv(chatLid: 'l2', displayName: 'Pendiente', unread: 2),
      ]);
      await tester.pumpWidget(host());

      await tester.tap(find.byKey(const Key('conversations.filter.unread')));
      await tester.pump();

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Leída'), findsNothing);
    });

    testWidgets('las archivadas viven bajo su filtro y "Todas" las oculta', (
      tester,
    ) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', displayName: 'Activa'),
        conv(chatLid: 'l2', displayName: 'Guardada', archived: true),
      ]);
      await tester.pumpWidget(host());

      // Vista default (Todas): la archivada no aparece.
      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('Guardada'), findsNothing);

      await tester.tap(find.byKey(const Key('conversations.filter.archived')));
      await tester.pump();

      expect(find.text('Guardada'), findsOneWidget);
      expect(find.text('Activa'), findsNothing);
    });

    testWidgets('las fijadas se ordenan primero', (tester) async {
      seed(<Conversation>[
        conv(chatLid: 'l1', displayName: 'Normal'),
        conv(chatLid: 'l2', displayName: 'Fijada', pinned: true),
      ]);
      await tester.pumpWidget(host());

      final normal = tester.getTopLeft(find.text('Normal'));
      final pinned = tester.getTopLeft(find.text('Fijada'));
      expect(pinned.dy, lessThan(normal.dy));
    });

    testWidgets('búsqueda sin coincidencias muestra "sin resultados"', (
      tester,
    ) async {
      seed(<Conversation>[conv(chatLid: 'l1', displayName: 'Carlos')]);
      await tester.pumpWidget(host());

      await tester.enterText(
        find.byKey(const Key('conversations.search')),
        'zzz',
      );
      await tester.pump();

      expect(find.byKey(const Key('conversations.no_results')), findsOneWidget);
    });
  });
}
