import 'dart:async';

import 'package:ataulfo/core/db/app_db.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_dao.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_datasource.dart';
import 'package:ataulfo/features/conversations/data/datasources/conversations_events_datasource.dart';
import 'package:ataulfo/features/conversations/data/repositories/conversations_repository_impl.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversation.dart';
import 'package:ataulfo/features/conversations/domain/entities/conversations_page.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_live_event.dart';
import 'package:ataulfo/features/conversations/domain/entities/inbox_query.dart';
import 'package:ataulfo/features/conversations/domain/failures/conversations_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements ConversationsDatasource {}

class _MockEvents extends Mock implements ConversationsEventsDatasource {}

Conversation conversation({
  String botId = 'bot-1',
  String chatLid = 'lid-1',
  bool attention = false,
}) => Conversation(
  botId: botId,
  chatLid: chatLid,
  kind: ConversationKind.dm,
  phone: '+502 5555 9012',
  isArchived: false,
  isPinned: false,
  isMarkedUnread: false,
  mutedUntil: null,
  needsAttention: attention,
  assistantId: 'assistant-1',
  assistantName: 'Ventas regionales',
  channelName: 'Ventas Guatemala',
  channelType: 'WA_UNOFFICIAL',
  labels: const <ConversationLabel>[],
);

void main() {
  late AppDb db;
  late ConversationsDao dao;
  late _MockDatasource datasource;
  late _MockEvents events;
  late ConversationsRepositoryImpl repository;
  late String activeOrgId;

  setUp(() {
    db = AppDb.forTesting(NativeDatabase.memory());
    activeOrgId = 'org-1';
    dao = ConversationsDao(db, activeOrgId: () => activeOrgId);
    datasource = _MockDatasource();
    events = _MockEvents();
    repository = ConversationsRepositoryImpl(
      datasource: datasource,
      events: events,
      dao: dao,
      now: () => DateTime.fromMillisecondsSinceEpoch(42),
    );
  });

  tearDown(() => db.close());

  test(
    'fetchPage escribe la página y watchAll la publica desde Drift',
    () async {
      const query = InboxQuery(status: InboxStatus.unread);
      final remote = conversation();
      when(() => datasource.list(query)).thenAnswer(
        (_) async => ConversationsPage(
          items: <Conversation>[remote],
          nextCursor: 'next',
        ),
      );

      final page = await repository.fetchPage(query);
      final cached = await repository.watchAll().first;

      expect(page.nextCursor, 'next');
      expect(cached, <Conversation>[remote]);
    },
  );

  test('una página posterior no borra la primera', () async {
    const first = InboxQuery();
    const second = InboxQuery(cursor: 'next');
    when(() => datasource.list(first)).thenAnswer(
      (_) async => ConversationsPage(
        items: <Conversation>[conversation(chatLid: 'first')],
        nextCursor: 'next',
      ),
    );
    when(() => datasource.list(second)).thenAnswer(
      (_) async => ConversationsPage(
        items: <Conversation>[conversation(chatLid: 'second')],
        nextCursor: null,
      ),
    );

    await repository.fetchPage(first);
    await repository.fetchPage(second);

    expect(await repository.watchAll().first, hasLength(2));
  });

  test('un pull en vuelo se escribe en la org que lo inició', () async {
    const query = InboxQuery();
    final request = Completer<ConversationsPage>();
    when(() => datasource.list(query)).thenAnswer((_) => request.future);

    final pending = repository.fetchPage(query);
    activeOrgId = 'org-2';
    request.complete(
      ConversationsPage(
        items: <Conversation>[conversation()],
        nextCursor: null,
      ),
    );
    await pending;

    expect(await repository.watchAll().first, isEmpty);
    activeOrgId = 'org-1';
    expect(await repository.watchAll().first, hasLength(1));
  });

  test('fallo HTTP conserva la caché offline', () async {
    const query = InboxQuery();
    when(() => datasource.list(query)).thenAnswer(
      (_) async => ConversationsPage(
        items: <Conversation>[conversation()],
        nextCursor: null,
      ),
    );
    await repository.fetchPage(query);
    when(
      () => datasource.list(query),
    ).thenThrow(const ConversationsNetworkFailure());

    await expectLater(
      repository.fetchPage(query),
      throwsA(isA<ConversationsNetworkFailure>()),
    );
    expect(await repository.watchAll().first, hasLength(1));
  });

  test('live usa una sola fuente org-scoped', () async {
    const event = InboxInvalidated(
      topic: 'message.inbound',
      botId: 'bot-1',
      chatLid: 'lid-1',
    );
    when(
      () => events.liveEvents(),
    ).thenAnswer((_) => Stream<InboxLiveEvent>.value(event));

    expect(await repository.live().first, event);
    verify(() => events.liveEvents()).called(1);
  });

  test('atención optimista y purga de permisos operan sobre caché', () async {
    const query = InboxQuery();
    when(() => datasource.list(query)).thenAnswer(
      (_) async => ConversationsPage(
        items: <Conversation>[conversation()],
        nextCursor: null,
      ),
    );
    await repository.fetchPage(query);

    await repository.markNeedsAttention('bot-1', 'lid-1');
    expect((await repository.watchAll().first).single.needsAttention, isTrue);

    await repository.clearCached();
    expect(await repository.watchAll().first, isEmpty);
  });
}
