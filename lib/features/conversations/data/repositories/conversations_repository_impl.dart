import '../../domain/entities/conversation.dart';
import '../../domain/failures/conversations_failure.dart';
import '../../domain/repositories/conversations_repository.dart';
import '../datasources/conversations_dao.dart';
import '../datasources/conversations_datasource.dart';
import '../mappers/conversation_row_mapper.dart';

/// Orquesta verdad local vs. remota (RFC-0001): la UI observa la DB
/// (`watchForBot`) y `refresh` trae el snapshot HTTP y lo escribe write-through
/// vía el DAO. Si el refresh falla por red, la caché local del watch permanece.
class ConversationsRepositoryImpl implements ConversationsRepository {
  ConversationsRepositoryImpl({
    required ConversationsDatasource datasource,
    required ConversationsDao dao,
    DateTime Function() now = DateTime.now,
  }) : _ds = datasource,
       _dao = dao,
       _now = now;

  final ConversationsDatasource _ds;
  final ConversationsDao _dao;
  final DateTime Function() _now;

  @override
  Stream<List<Conversation>> watchForBot(String botId) => _dao
      .watchForBot(botId)
      .map(
        (rows) =>
            rows.map(ConversationRowMapper.rowToEntity).toList(growable: false),
      )
      // El contrato del puerto es surtir solo ConversationsFailure tipadas: un
      // error crudo de drift en la consulta del watch se traduce para que el
      // bloc lo entienda en vez de escapar como error asíncrono no manejado.
      .handleError(
        (Object _) => throw const UnknownConversationsFailure(),
        test: (Object? e) => e is! ConversationsFailure,
      );

  @override
  Future<void> refresh(String botId) async {
    try {
      final fresh = await _ds.listForBot(botId);
      final syncedAtMs = _now().millisecondsSinceEpoch;
      final rows = fresh
          .map(
            (c) => ConversationRowMapper.entityToCompanion(
              botId,
              c,
              syncedAtMs: syncedAtMs,
            ),
          )
          .toList(growable: false);
      await _dao.replaceForBot(botId, rows);
    } on ConversationsFailure {
      rethrow; // el datasource ya surte fallos tipados.
    } catch (_) {
      // La escritura local (drift) puede fallar con un error no tipado (p. ej.
      // "database is locked" si otro escritor toca la DB); el bloc solo
      // entiende ConversationsFailure.
      throw const UnknownConversationsFailure();
    }
  }
}
