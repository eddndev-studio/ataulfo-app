import 'dart:async';

import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversations_page.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_live_event.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:ataulfo/features/conversations/domain/repositories/conversations_repository.dart';
import 'package:ataulfo/features/conversations/presentation/bloc/conversations_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ConversationsRepository {}

Conversation conversation(
  String botId,
  String chatLid, {
  int timestamp = 1,
  int unreadCount = 0,
  bool attention = false,
  List<ConversationLabel> labels = const <ConversationLabel>[],
}) => Conversation(
  botId: botId,
  chatLid: chatLid,
  kind: ConversationKind.dm,
  phone: '+502 5555 9012',
  displayName: 'Comercial Rivera',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  unreadCount: unreadCount,
  lastMessageTimestampMs: timestamp,
  needsAttention: attention,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas $botId',
  channelType: 'WA_UNOFFICIAL',
  labels: labels,
);

Future<void> tick([int count = 1]) async {
  for (var i = 0; i < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _MockRepository repository;
  late StreamController<List<Conversation>> cache;
  late StreamController<InboxLiveEvent> live;

  setUpAll(() => registerFallbackValue(const InboxQuery()));

  setUp(() {
    repository = _MockRepository();
    cache = StreamController<List<Conversation>>.broadcast();
    live = StreamController<InboxLiveEvent>.broadcast();
    when(() => repository.watchAll()).thenAnswer((_) => cache.stream);
    when(() => repository.live()).thenAnswer((_) => live.stream);
    when(() => repository.clearCached()).thenAnswer((_) async {});
    when(
      () => repository.markNeedsAttention(any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await cache.close();
    await live.close();
  });

  ConversationsBloc build({
    InboxQuery query = const InboxQuery(),
    Duration searchDebounce = Duration.zero,
  }) => ConversationsBloc(
    repo: repository,
    initialQuery: query,
    searchDebounce: searchDebounce,
    liveDebounce: Duration.zero,
  );

  test(
    'load consulta org-scoped y conserva chats iguales de dos bots',
    () async {
      final rows = <Conversation>[
        conversation('b1', 'same', timestamp: 20),
        conversation('b2', 'same', timestamp: 10),
      ];
      when(() => repository.fetchPage(const InboxQuery())).thenAnswer(
        (_) async => ConversationsPage(items: rows, nextCursor: 'next'),
      );
      final bloc = build();

      bloc.add(const ConversationsLoadRequested());
      await tick(2);
      cache.add(rows);
      await tick(2);

      expect(bloc.state.phase, ConversationsPhase.ready);
      expect(bloc.state.items, hasLength(2));
      expect(bloc.state.items.map((c) => c.stableKey).toSet(), hasLength(2));
      expect(bloc.state.nextCursor, 'next');
      await bloc.close();
    },
  );

  test('la respuesta REST fresca gana a una fila vieja de caché', () async {
    final stale = conversation('b1', 'same', timestamp: 10);
    final fresh = conversation('b1', 'same', timestamp: 90, attention: true);
    final request = Completer<ConversationsPage>();
    when(
      () => repository.fetchPage(const InboxQuery()),
    ).thenAnswer((_) => request.future);
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(2);
    cache.add(<Conversation>[stale]);
    await tick(2);

    request.complete(
      ConversationsPage(items: <Conversation>[fresh], nextCursor: null),
    );
    await tick(2);

    expect(bloc.state.items, <Conversation>[fresh]);
    await bloc.close();
  });

  test('tras sincronizar REST, una mutación local vuelve a ganar', () async {
    final stale = conversation('b1', 'same', timestamp: 10);
    final fresh = conversation('b1', 'same', timestamp: 90);
    final optimistic = conversation(
      'b1',
      'same',
      timestamp: 90,
      attention: true,
    );
    final request = Completer<ConversationsPage>();
    when(
      () => repository.fetchPage(const InboxQuery()),
    ).thenAnswer((_) => request.future);
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(2);
    cache.add(<Conversation>[stale]);
    await tick(2);
    request.complete(
      ConversationsPage(items: <Conversation>[fresh], nextCursor: null),
    );
    await tick(2);

    cache.add(<Conversation>[fresh]);
    await tick(2);
    cache.add(<Conversation>[optimistic]);
    await tick(2);

    expect(bloc.state.items, <Conversation>[optimistic]);
    await bloc.close();
  });

  test('una lectura local retira la fila del filtro no leídas', () async {
    final unread = conversation('b1', 'same', unreadCount: 2);
    final read = conversation('b1', 'same');
    const query = InboxQuery(status: InboxStatus.unread);
    when(() => repository.fetchPage(query)).thenAnswer(
      (_) async =>
          ConversationsPage(items: <Conversation>[unread], nextCursor: null),
    );
    final bloc = build(query: query)..add(const ConversationsLoadRequested());
    await tick(3);
    cache.add(<Conversation>[unread]);
    await tick(2);
    cache.add(<Conversation>[read]);
    await tick(2);

    expect(bloc.state.items, isEmpty);
    await bloc.close();
  });

  test('catálogo vivo elimina canales borrados de la caché offline', () async {
    final kept = conversation('b1', 'kept', timestamp: 20);
    final deleted = conversation('b2', 'deleted', timestamp: 10);
    final request = Completer<ConversationsPage>();
    when(
      () => repository.fetchPage(const InboxQuery()),
    ).thenAnswer((_) => request.future);
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(2);
    cache.add(<Conversation>[kept, deleted]);
    await tick(2);
    request.completeError(const ConversationsNetworkFailure());
    await tick(2);

    bloc.add(const ConversationsValidChannelsChanged(<String>{'b1'}));
    await tick(2);

    expect(bloc.state.items, <Conversation>[kept]);
    expect(bloc.state.isOffline, isTrue);
    await bloc.close();
  });

  test('catálogo vivo elimina canales borrados de una página REST', () async {
    final kept = conversation('b1', 'kept', timestamp: 20);
    final deleted = conversation('b2', 'deleted', timestamp: 10);
    when(() => repository.fetchPage(const InboxQuery())).thenAnswer(
      (_) async => ConversationsPage(
        items: <Conversation>[kept, deleted],
        nextCursor: null,
      ),
    );
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(3);

    bloc.add(const ConversationsValidChannelsChanged(<String>{'b1'}));
    await tick(2);

    expect(bloc.state.items, <Conversation>[kept]);
    await bloc.close();
  });

  test(
    'cambiar filtros reinicia cursor y compone estado, canal y labels',
    () async {
      when(() => repository.fetchPage(any())).thenAnswer(
        (invocation) async =>
            const ConversationsPage(items: <Conversation>[], nextCursor: null),
      );
      final bloc = build(
        query: const InboxQuery(cursor: 'stale', botId: 'bot-old'),
      );
      bloc.add(const ConversationsLoadRequested());
      await tick(2);

      bloc
        ..add(const ConversationsStatusChanged(InboxStatus.attention))
        ..add(const ConversationsChannelChanged('bot-1'))
        ..add(const ConversationsLabelToggled('vip'))
        ..add(const ConversationsLabelToggled('lead'));
      await tick(5);

      expect(bloc.state.query.status, InboxStatus.attention);
      expect(bloc.state.query.botId, 'bot-1');
      expect(bloc.state.query.labelIds, <String>{'vip', 'lead'});
      expect(bloc.state.query.cursor, isNull);
      final queries = verify(
        () => repository.fetchPage(captureAny()),
      ).captured.cast<InboxQuery>();
      expect(queries.last.cursor, isNull);
      expect(queries.last.labelIds, <String>{'vip', 'lead'});
      await bloc.close();
    },
  );

  test('limpiar filtros cancela una búsqueda pendiente', () async {
    when(() => repository.fetchPage(any())).thenAnswer(
      (_) async =>
          const ConversationsPage(items: <Conversation>[], nextCursor: null),
    );
    final bloc = build(searchDebounce: const Duration(milliseconds: 20))
      ..add(const ConversationsLoadRequested());
    await tick(2);

    bloc
      ..add(const ConversationsSearchChanged('búsqueda pendiente'))
      ..add(const ConversationsFiltersCleared());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.query.search, isEmpty);
    await bloc.close();
  });

  test(
    'loadMore deduplica identidad observada en páginas concurrentes',
    () async {
      final first = conversation('b1', 'first', timestamp: 30);
      final duplicate = conversation('b1', 'duplicate', timestamp: 20);
      final third = conversation('b2', 'third', timestamp: 10);
      when(() => repository.fetchPage(const InboxQuery())).thenAnswer(
        (_) async => ConversationsPage(
          items: <Conversation>[first, duplicate],
          nextCursor: 'next',
        ),
      );
      when(
        () => repository.fetchPage(const InboxQuery(cursor: 'next')),
      ).thenAnswer(
        (_) async => ConversationsPage(
          items: <Conversation>[duplicate, third],
          nextCursor: null,
        ),
      );
      final bloc = build()..add(const ConversationsLoadRequested());
      await tick(2);
      cache.add(<Conversation>[first, duplicate]);
      await tick(2);

      bloc.add(const ConversationsLoadMoreRequested());
      await tick(2);
      cache.add(<Conversation>[first, duplicate, third]);
      await tick(2);

      expect(bloc.state.items.map((c) => c.stableKey).toSet(), hasLength(3));
      expect(bloc.state.items, hasLength(3));
      expect(bloc.state.hasMore, isFalse);
      await bloc.close();
    },
  );

  test('red caída sirve caché con indicador offline', () async {
    final cached = conversation('b1', 'cached');
    final request = Completer<ConversationsPage>();
    when(
      () => repository.fetchPage(const InboxQuery()),
    ).thenAnswer((_) => request.future);
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(2);
    cache.add(<Conversation>[cached]);
    await tick(2);
    request.completeError(const ConversationsNetworkFailure());
    await tick(2);

    expect(bloc.state.phase, ConversationsPhase.ready);
    expect(bloc.state.items, <Conversation>[cached]);
    expect(bloc.state.isOffline, isTrue);
    await bloc.close();
  });

  test('403 purga caché y nunca la sigue mostrando', () async {
    when(
      () => repository.fetchPage(const InboxQuery()),
    ).thenThrow(const ConversationsForbiddenFailure());
    final bloc = build()..add(const ConversationsLoadRequested());
    cache.add(<Conversation>[conversation('b1', 'stale')]);
    await tick(4);

    expect(bloc.state.phase, ConversationsPhase.failure);
    expect(bloc.state.items, isEmpty);
    verify(() => repository.clearCached()).called(1);
    await bloc.close();
  });

  test('evento de atención actualiza caché y reconcilia REST', () async {
    when(() => repository.fetchPage(any())).thenAnswer(
      (_) async =>
          const ConversationsPage(items: <Conversation>[], nextCursor: null),
    );
    final bloc = build()..add(const ConversationsLoadRequested());
    await tick(2);
    clearInteractions(repository);
    when(() => repository.watchAll()).thenAnswer((_) => cache.stream);
    when(() => repository.live()).thenAnswer((_) => live.stream);
    when(() => repository.clearCached()).thenAnswer((_) async {});
    when(() => repository.fetchPage(any())).thenAnswer(
      (_) async =>
          const ConversationsPage(items: <Conversation>[], nextCursor: null),
    );
    when(
      () => repository.markNeedsAttention(any(), any()),
    ).thenAnswer((_) async {});

    live.add(
      const InboxInvalidated(
        topic: 'agent.alert',
        botId: 'bot-1',
        chatLid: 'lid-1',
        needsAttention: true,
      ),
    );
    await tick(5);

    verify(() => repository.markNeedsAttention('bot-1', 'lid-1')).called(1);
    verify(() => repository.fetchPage(const InboxQuery())).called(1);
    await bloc.close();
  });

  test('etiqueta borrada sale de la selección y reconsulta', () async {
    when(() => repository.fetchPage(any())).thenAnswer(
      (_) async =>
          const ConversationsPage(items: <Conversation>[], nextCursor: null),
    );
    final bloc = build(
      query: const InboxQuery(labelIds: <String>{'vip', 'deleted'}),
    )..add(const ConversationsLoadRequested());
    await tick(2);

    bloc.add(const ConversationsValidLabelsChanged(<String>{'vip'}));
    await tick(3);

    expect(bloc.state.query.labelIds, <String>{'vip'});
    await bloc.close();
  });

  test(
    'catálogo vivo retira una etiqueta borrada de filas cacheadas',
    () async {
      const vip = ConversationLabel(id: 'vip', name: 'VIP', color: '#176B5B');
      const deleted = ConversationLabel(
        id: 'deleted',
        name: 'Eliminada',
        color: '#C57B57',
      );
      when(
        () => repository.fetchPage(const InboxQuery()),
      ).thenThrow(const ConversationsNetworkFailure());
      final bloc = build()..add(const ConversationsLoadRequested());
      await tick(2);
      cache.add(<Conversation>[
        conversation(
          'b1',
          'cached',
          labels: const <ConversationLabel>[vip, deleted],
        ),
      ]);
      await tick(3);

      bloc.add(const ConversationsValidLabelsChanged(<String>{'vip'}));
      await tick(2);

      expect(bloc.state.items.single.labels, const <ConversationLabel>[vip]);
      await bloc.close();
    },
  );
}
