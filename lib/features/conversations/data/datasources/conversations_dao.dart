import 'package:drift/drift.dart';

import '../../../../core/db/app_db.dart';

/// Acceso local (drift) a la bandeja de conversaciones. La UI observa
/// [watchForBot]; el refresh HTTP escribe vía [replaceForBot].
class ConversationsDao {
  ConversationsDao(this._db);

  final AppDb _db;

  /// Conversaciones del bot, recientes primero. Las marcas nulas
  /// (`lastMessageTimestampMs` ausente = sin mensajes) caen al final con DESC.
  /// La UI parte luego por fijadas y aplica filtros; aquí solo va el orden base.
  Stream<List<ConversationRow>> watchForBot(String botId) {
    return (_db.select(_db.conversations)
          ..where((c) => c.botId.equals(botId))
          ..orderBy([(c) => OrderingTerm.desc(c.lastMessageTimestampMs)]))
        .watch();
  }

  /// Reemplaza el conjunto del bot por el snapshot fresco del backend (la
  /// bandeja llega completa). En una transacción → el `watch` emite una sola
  /// vez con el set ya consistente, sin estado intermedio vacío.
  Future<void> replaceForBot(String botId, List<ConversationsCompanion> rows) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.conversations,
      )..where((c) => c.botId.equals(botId))).go();
      await _db.batch((b) => b.insertAll(_db.conversations, rows));
    });
  }
}
