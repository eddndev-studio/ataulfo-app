import 'package:drift/drift.dart';

import '../../../../core/db/app_db.dart';

/// Caché reconstruible de la Bandeja org-scoped. Cada página hace upsert por
/// `(botId, chatLid)`; nunca reemplaza el set completo ni borra otras páginas.
class ConversationsDao {
  ConversationsDao(this._db, {required String Function() activeOrgId})
    : _activeOrgId = activeOrgId;

  final AppDb _db;
  final String Function() _activeOrgId;

  String get activeOrgId => _activeOrgId().trim();

  Stream<List<ConversationRow>> watchAll() {
    final orgId = activeOrgId;
    return (_db.select(_db.conversations)
          ..where((row) => row.orgId.equals(orgId))
          ..orderBy([
            (row) => OrderingTerm.desc(row.isPinned),
            (row) => OrderingTerm.desc(row.lastMessageTimestampMs),
            (row) => OrderingTerm.asc(row.botId),
            (row) => OrderingTerm.asc(row.chatLid),
          ]))
        .watch();
  }

  Future<void> upsertPage(List<ConversationsCompanion> rows) {
    if (rows.isEmpty) return Future<void>.value();
    return _db.batch(
      (batch) => batch.insertAllOnConflictUpdate(_db.conversations, rows),
    );
  }

  Future<void> clearUnread(String botId, String chatLid) {
    return (_db.update(_db.conversations)..where(
          (row) =>
              row.orgId.equals(activeOrgId) &
              row.botId.equals(botId) &
              row.chatLid.equals(chatLid),
        ))
        .write(
          const ConversationsCompanion(
            unreadCount: Value(0),
            isMarkedUnread: Value(false),
            needsAttention: Value(false),
          ),
        );
  }

  Future<void> markNeedsAttention(String botId, String chatLid) {
    return (_db.update(_db.conversations)..where(
          (row) =>
              row.orgId.equals(activeOrgId) &
              row.botId.equals(botId) &
              row.chatLid.equals(chatLid),
        ))
        .write(const ConversationsCompanion(needsAttention: Value(true)));
  }

  Future<void> clearThreadProjection(String botId, String chatLid) {
    return (_db.update(_db.conversations)..where(
          (row) =>
              row.orgId.equals(activeOrgId) &
              row.botId.equals(botId) &
              row.chatLid.equals(chatLid),
        ))
        .write(
          const ConversationsCompanion(
            unreadCount: Value(0),
            isMarkedUnread: Value(false),
            needsAttention: Value(false),
            lastMessagePreview: Value(null),
            lastMessageType: Value(null),
            lastMessageDirection: Value(null),
            lastMessageTimestampMs: Value(null),
          ),
        );
  }

  Future<void> clearCached() => (_db.delete(
    _db.conversations,
  )..where((row) => row.orgId.equals(activeOrgId))).go();
}
