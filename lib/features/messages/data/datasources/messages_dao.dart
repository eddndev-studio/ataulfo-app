import 'package:drift/drift.dart';

import '../../../../core/db/app_db.dart';
import '../../domain/entities/message.dart';
import '../mappers/message_row_mapper.dart';

/// Acceso local (drift) al hilo de mensajes. La UI observa [watchThread]; las
/// escrituras (pull HTTP, eco de envío, realtime SSE) entran por [upsertMessages]
/// y [applyStatus]. El `status` es **monótono**: nunca retrocede en un upsert ni
/// en un recibo (SENT<DELIVERED<READ, FAILED terminal — `MessageStatus.transition`).
class MessagesDao {
  MessagesDao(this._db, {DateTime Function() now = DateTime.now}) : _now = now;

  final AppDb _db;
  final DateTime Function() _now;

  /// Mensajes del hilo en orden ascendente (viejo→nuevo), con desempate estable
  /// por `externalId`. El contenido es inmutable por `externalId` (PK I-M1).
  Stream<List<MessageRow>> watchThread(String botId, String chatLid) {
    return (_db.select(_db.messages)
          ..where((m) => m.botId.equals(botId) & m.chatLid.equals(chatLid))
          ..orderBy([
            (m) => OrderingTerm.asc(m.timestampMs),
            (m) => OrderingTerm.asc(m.externalId),
          ]))
        .watch();
  }

  /// Upsert por `(botId, externalId)` que respeta la monotonía del status: si el
  /// mensaje ya existe, el status sólo avanza (un snapshot HTTP con status viejo
  /// no pisa un recibo más nuevo ya aplicado). El resto de campos son inmutables.
  Future<void> upsertMessages(String botId, List<Message> msgs) {
    return _db.transaction(() async {
      final syncedAtMs = _now().millisecondsSinceEpoch;
      for (final m in msgs) {
        final existing = await _byId(botId, m.externalId);
        final resolved = _resolveStatus(_statusOf(existing), m.status);
        final companion = MessageRowMapper.toCompanion(
          botId,
          m,
          syncedAtMs: syncedAtMs,
        ).copyWith(status: Value(resolved?.name));
        await _db.into(_db.messages).insertOnConflictUpdate(companion);
      }
    });
  }

  /// Aplica un recibo de estado (LiveStatus) a un mensaje existente, sólo si
  /// avanza. Si el mensaje aún no está local, se ignora (el reconcile lo traerá).
  Future<void> applyStatus(
    String botId,
    String externalId,
    MessageStatus status,
  ) async {
    final existing = await _byId(botId, externalId);
    if (existing == null) return;
    final advanced = MessageStatus.transition(_statusOf(existing), status);
    if (advanced == null) return;
    await (_db.update(_db.messages)..where(
          (t) => t.botId.equals(botId) & t.externalId.equals(externalId),
        ))
        .write(MessagesCompanion(status: Value(advanced.name)));
  }

  /// Cursor de backfill histórico persistido para `(botId, chatLid)`.
  Future<({String? cursor, bool reachedStart})> threadCursor(
    String botId,
    String chatLid,
  ) async {
    final row =
        await (_db.select(_db.syncCursors)
              ..where((c) => c.botId.equals(botId) & c.chatLid.equals(chatLid)))
            .getSingleOrNull();
    return (
      cursor: row?.oldestCursor,
      reachedStart: row?.reachedStart ?? false,
    );
  }

  Future<void> setThreadCursor(
    String botId,
    String chatLid, {
    required String? oldestCursor,
    required bool reachedStart,
  }) {
    return _db
        .into(_db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            botId: botId,
            chatLid: chatLid,
            oldestCursor: Value(oldestCursor),
            reachedStart: Value(reachedStart),
          ),
        );
  }

  /// Borra los mensajes y el cursor de backfill de UN chat (la limpieza local
  /// tras el 204 del vaciado de historial, S07 RF#10). En una transacción: el
  /// watch del hilo emite una sola vez, ya vacío. Sin el cursor, el hilo
  /// arranca fresco y no intenta paginar histórico que ya no existe.
  Future<void> deleteThread(String botId, String chatLid) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.messages,
      )..where((m) => m.botId.equals(botId) & m.chatLid.equals(chatLid))).go();
      await (_db.delete(
        _db.syncCursors,
      )..where((c) => c.botId.equals(botId) & c.chatLid.equals(chatLid))).go();
    });
  }

  Future<MessageRow?> _byId(String botId, String externalId) {
    return (_db.select(_db.messages)..where(
          (t) => t.botId.equals(botId) & t.externalId.equals(externalId),
        ))
        .getSingleOrNull();
  }

  static MessageStatus? _statusOf(MessageRow? r) =>
      (r?.status == null) ? null : MessageStatus.values.byName(r!.status!);

  /// Status resultante de fundir el existente con el entrante respetando la
  /// monotonía: entrante nulo conserva el actual; sin actual gana el entrante;
  /// si la transición no avanza, se conserva el actual.
  static MessageStatus? _resolveStatus(
    MessageStatus? current,
    MessageStatus? incoming,
  ) {
    if (incoming == null) return current;
    if (current == null) return incoming;
    return MessageStatus.transition(current, incoming) ?? current;
  }
}
