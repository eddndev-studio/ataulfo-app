import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversations_repository.dart';
import '../datasources/conversations_datasource.dart';

/// Implementación trivial del puerto: el listado refresca contra el backend
/// en cada open (sin cache local en esta capa). Cuando aterrice RFC-0001
/// (cache + sync), esta clase orquestará verdad local vs. remota; hoy delega.
class ConversationsRepositoryImpl implements ConversationsRepository {
  ConversationsRepositoryImpl({required ConversationsDatasource datasource})
    : _ds = datasource;

  final ConversationsDatasource _ds;

  @override
  Future<List<Conversation>> listForBot(String botId) => _ds.listForBot(botId);
}
