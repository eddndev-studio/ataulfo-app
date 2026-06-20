import '../../domain/entities/pa_conversation.dart';
import '../../domain/entities/pa_message.dart';
import '../../domain/entities/pa_models.dart';
import '../../domain/entities/pa_progress.dart';
import '../../domain/repositories/platform_agent_repository.dart';
import '../datasources/platform_agent_datasource.dart';
import '../datasources/platform_agent_events_datasource.dart';

/// Impl delgada del chat: delega al datasource. Existe como seam de DI para
/// el bloc y los tests.
class PlatformAgentRepositoryImpl implements PlatformAgentRepository {
  PlatformAgentRepositoryImpl({required PlatformAgentDatasource datasource})
    : _ds = datasource;

  final PlatformAgentDatasource _ds;

  @override
  Future<PaConversation> createConversation({String title = ''}) =>
      _ds.createConversation(title: title);

  @override
  Future<List<PaConversation>> listConversations() => _ds.listConversations();

  @override
  Future<PaMessagesPage> listMessages({
    required String conversationId,
    String cursor = '',
    int limit = 0,
  }) => _ds.listMessages(
    conversationId: conversationId,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<PaMessage> sendMessage({
    required String conversationId,
    required String content,
    String? model,
  }) => _ds.sendMessage(
    conversationId: conversationId,
    content: content,
    model: model,
  );

  @override
  Future<PaModels> listModels() => _ds.listModels();
}

/// Impl del stream de progreso: delega al datasource SSE.
class PlatformAgentEventsImpl implements PlatformAgentEvents {
  PlatformAgentEventsImpl({required PlatformAgentEventsDatasource datasource})
    : _ds = datasource;

  final PlatformAgentEventsDatasource _ds;

  @override
  Stream<PaProgressEvent> progress(String conversationId) =>
      _ds.progress(conversationId);
}
