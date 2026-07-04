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

  /// Baja a cero los no-leídos de una fila (contador + marca manual) de forma
  /// local. Es el write-through optimista de interactuar con un chat (abrirlo
  /// marca leído): la bandeja observa esta tabla, así el badge desaparece en el
  /// acto sin esperar el pull. No inserta filas ausentes (`.write` sobre el
  /// filtro): si la fila aún no está en caché, no hay badge que bajar. El
  /// snapshot autoritativo del backend reconcilia en el próximo `replaceForBot`.
  Future<void> clearUnread(String botId, String chatLid) {
    return (_db.update(
      _db.conversations,
    )..where((c) => c.botId.equals(botId) & c.chatLid.equals(chatLid))).write(
      const ConversationsCompanion(
        unreadCount: Value(0),
        isMarkedUnread: Value(false),
      ),
    );
  }

  /// Vacía la proyección de actividad de una fila tras el vaciado de
  /// historial (S07 RF#10): la bandeja no debe previsualizar un mensaje que
  /// ya no existe. Write-through optimista con el mismo contrato que
  /// [clearUnread]: no inserta filas ausentes y el snapshot autoritativo del
  /// backend reconcilia en el próximo `replaceForBot`.
  Future<void> clearThreadProjection(String botId, String chatLid) {
    return (_db.update(
      _db.conversations,
    )..where((c) => c.botId.equals(botId) & c.chatLid.equals(chatLid))).write(
      const ConversationsCompanion(
        unreadCount: Value(0),
        isMarkedUnread: Value(false),
        lastMessagePreview: Value(null),
        lastMessageType: Value(null),
        lastMessageDirection: Value(null),
        lastMessageTimestampMs: Value(null),
      ),
    );
  }
}
