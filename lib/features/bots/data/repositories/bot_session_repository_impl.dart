import '../../domain/entities/connect_link.dart';
import '../../domain/repositories/bot_session_repository.dart';
import '../datasources/bot_session_datasource.dart';

/// Implementación del puerto de emparejamiento. Hoy delega 1:1 en el
/// datasource; cuando aterrice la cache (RFC-0001) este es el punto donde
/// se orquestaría verdad local vs. remota sin tocar dominio ni presentación.
class BotSessionRepositoryImpl implements BotSessionRepository {
  BotSessionRepositoryImpl({required BotSessionDatasource datasource})
    : _ds = datasource;

  final BotSessionDatasource _ds;

  @override
  Future<void> startSession(String botId) => _ds.startSession(botId);

  @override
  Future<void> stopSession(String botId) => _ds.stopSession(botId);

  @override
  Future<ConnectLink> issueConnectLink(String botId) =>
      _ds.issueConnectLink(botId);

  @override
  Future<void> clearConversations(String botId) =>
      _ds.clearConversations(botId);

  @override
  Future<void> resetSessions(String botId) => _ds.resetSessions(botId);

  @override
  Future<void> wipeCredentials(String botId) => _ds.wipeCredentials(botId);
}
