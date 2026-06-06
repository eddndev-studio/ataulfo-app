import '../../domain/entities/message.dart';
import '../../domain/entities/message_page.dart';
import '../../domain/entities/thread_live_event.dart';
import '../../domain/repositories/messages_repository.dart';
import '../datasources/messages_datasource.dart';
import '../datasources/messages_events_datasource.dart';

/// Implementación trivial del puerto: la cola se trae por HTTP al vuelo y el
/// flujo en vivo se delega al datasource de eventos (SSE). Sin cache local en
/// esta capa; cuando aterrice RFC-0001 (cache + sync), esta clase orquestará
/// verdad local vs. remota. Hoy delega.
class MessagesRepositoryImpl implements MessagesRepository {
  MessagesRepositoryImpl({
    required MessagesDatasource datasource,
    required MessagesEventsDatasource events,
  }) : _ds = datasource,
       _events = events;

  final MessagesDatasource _ds;
  final MessagesEventsDatasource _events;

  @override
  Future<MessagePage> thread(
    String botId,
    String chatLid, {
    String? cursor,
    int? limit,
  }) => _ds.thread(botId, chatLid, cursor: cursor, limit: limit);

  @override
  Future<Message> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content = '',
    String? mediaRef,
  }) => _ds.send(
    botId,
    chatLid,
    clientToken: clientToken,
    type: type,
    content: content,
    mediaRef: mediaRef,
  );

  @override
  Future<int> markRead(String botId, String chatLid, {String? upToMessageId}) =>
      _ds.markRead(botId, chatLid, upToMessageId: upToMessageId);

  @override
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  }) => _ds.react(botId, chatLid, messageId: messageId, emoji: emoji);

  @override
  Stream<ThreadLiveEvent> live(String botId) => _events.threadEvents(botId);
}
