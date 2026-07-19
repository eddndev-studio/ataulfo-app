import '../../domain/entities/conversation.dart';
import '../../domain/entities/conversations_page.dart';
import '../../domain/entities/inbox_live_event.dart';
import '../../domain/entities/inbox_query.dart';
import '../../domain/failures/conversations_failure.dart';
import '../../domain/repositories/conversations_repository.dart';
import '../datasources/conversations_dao.dart';
import '../datasources/conversations_datasource.dart';
import '../datasources/conversations_events_datasource.dart';
import '../mappers/conversation_row_mapper.dart';

class ConversationsRepositoryImpl implements ConversationsRepository {
  ConversationsRepositoryImpl({
    required ConversationsDatasource datasource,
    required ConversationsEventsDatasource events,
    required ConversationsDao dao,
    DateTime Function() now = DateTime.now,
  }) : _datasource = datasource,
       _events = events,
       _dao = dao,
       _now = now;

  final ConversationsDatasource _datasource;
  final ConversationsEventsDatasource _events;
  final ConversationsDao _dao;
  final DateTime Function() _now;

  @override
  Stream<List<Conversation>> watchAll() => _dao
      .watchAll()
      .map(
        (rows) =>
            rows.map(ConversationRowMapper.rowToEntity).toList(growable: false),
      )
      .handleError(
        (Object _) => throw const UnknownConversationsFailure(),
        test: (Object? error) => error is! ConversationsFailure,
      );

  @override
  Future<ConversationsPage> fetchPage(InboxQuery query) async {
    // El tenant se captura ANTES del await. Un cambio de organización puede
    // ocurrir mientras la petición está en vuelo; atribuir la respuesta al
    // valor vivo posterior mezclaría la proyección anterior con la nueva org.
    final requestOrgId = _dao.activeOrgId;
    try {
      final page = await _datasource.list(query);
      final syncedAtMs = _now().millisecondsSinceEpoch;
      await _dao.upsertPage(
        page.items
            .map(
              (item) => ConversationRowMapper.entityToCompanion(
                item,
                orgId: requestOrgId,
                syncedAtMs: syncedAtMs,
              ),
            )
            .toList(growable: false),
      );
      return page;
    } on ConversationsFailure {
      rethrow;
    } catch (_) {
      throw const UnknownConversationsFailure();
    }
  }

  @override
  Stream<InboxLiveEvent> live() => _events.liveEvents();

  @override
  Future<void> markNeedsAttention(String botId, String chatLid) =>
      _dao.markNeedsAttention(botId, chatLid);

  @override
  Future<void> clearCached() => _dao.clearCached();
}
