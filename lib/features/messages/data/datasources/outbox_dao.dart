import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_db.dart';

/// Acceso local (drift) a la cola de escrituras durables (outbox). El
/// `SyncCoordinator` la drena; la UI observa [watchForChat] para pintar las
/// burbujas pendientes y su estado.
///
/// `state` ∈ {`pending`, `sending`, `failed`}: `pending` es drenable; `sending`
/// marca una op en vuelo (se resetea a `pending` al arrancar si quedó huérfana
/// por un cierre a media-POST); `failed` es un fallo TERMINAL que no se
/// reintenta solo (sólo por acción del usuario). `clientToken` es la clave de
/// idempotencia que se **reusa** en cada reintento — nunca se regenera.
class OutboxDao {
  OutboxDao(this._db, {DateTime Function() now = DateTime.now}) : _now = now;

  final AppDb _db;
  final DateTime Function() _now;

  /// Encola un envío de mensaje (texto o media). El `payload` lleva lo que la UI
  /// necesita para pintar la burbuja antes de confirmar (`type`/`content`/`mediaRef`).
  Future<int> enqueueSend({
    required String botId,
    required String chatLid,
    required String clientToken,
    required String type,
    required String content,
    String? mediaRef,
  }) {
    final nowMs = _nowMs();
    final payload = jsonEncode(<String, dynamic>{
      'type': type,
      'content': content,
      'mediaRef': ?mediaRef,
    });
    return _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            botId: botId,
            chatLid: chatLid,
            opType: 'send_message',
            clientToken: Value(clientToken),
            payload: payload,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );
  }

  /// Encola un mark-read durable (palomitas). **Coalesce por chat**: borra los
  /// `mark_read` pendientes/fallidos del chat antes de insertar — abrir el chat
  /// lo dispara repetido y no debe acumularse (es idempotente y sin orden
  /// relevante). Sin `clientToken` (no necesita idempotency-key del wire).
  Future<int> enqueueMarkRead({
    required String botId,
    required String chatLid,
    String? upToMessageId,
  }) {
    final nowMs = _nowMs();
    final payload = jsonEncode(<String, dynamic>{
      'upToMessageId': ?upToMessageId,
    });
    return _db.transaction(() async {
      await (_db.delete(_db.outbox)..where(
            (o) =>
                o.botId.equals(botId) &
                o.chatLid.equals(chatLid) &
                o.opType.equals('mark_read') &
                o.state.isIn(const ['pending', 'failed']),
          ))
          .go();
      return _db
          .into(_db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: botId,
              chatLid: chatLid,
              opType: 'mark_read',
              payload: payload,
              createdAtMs: nowMs,
              updatedAtMs: nowMs,
            ),
          );
    });
  }

  /// Encola una reacción durable (`emoji` vacío la quita). **Coalesce por
  /// (chat, messageId)**: borra las reacciones pendientes/fallidas del MISMO
  /// mensaje antes de insertar, para que sólo quede encolada la última intención
  /// — si no, una reacción vieja atascada podría reenviarse DESPUÉS de una nueva
  /// y ganar (estado erróneo), porque las reacciones no preservan orden FIFO.
  Future<int> enqueueReact({
    required String botId,
    required String chatLid,
    required String messageId,
    required String emoji,
  }) {
    final nowMs = _nowMs();
    final payload = jsonEncode(<String, dynamic>{
      'messageId': messageId,
      'emoji': emoji,
    });
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.outbox)..where(
                (o) =>
                    o.botId.equals(botId) &
                    o.chatLid.equals(chatLid) &
                    o.opType.equals('react') &
                    o.state.isIn(const ['pending', 'failed']),
              ))
              .get();
      for (final row in existing) {
        try {
          final p = jsonDecode(row.payload) as Map<String, dynamic>;
          if (p['messageId'] == messageId) {
            await (_db.delete(
              _db.outbox,
            )..where((o) => o.id.equals(row.id))).go();
          }
        } catch (_) {
          // Fila corrupta: déjala; el coordinador la marcará terminal.
        }
      }
      return _db
          .into(_db.outbox)
          .insert(
            OutboxCompanion.insert(
              botId: botId,
              chatLid: chatLid,
              opType: 'react',
              payload: payload,
              createdAtMs: nowMs,
              updatedAtMs: nowMs,
            ),
          );
    });
  }

  /// ¿Existe una reacción MÁS NUEVA (id mayor) para el mismo mensaje? Sirve para
  /// re-coalescer en el dispatch: una reacción vieja que sobrevivió (estaba en
  /// vuelo / huérfana) no debe POSTearse si ya hay una intención posterior, o
  /// aterrizaría DESPUÉS y pisaría la última. El `id` autoincremental es la clave
  /// de "más nuevo" (dos en el mismo ms empatan por createdAt). Cualquier estado
  /// cuenta: una reacción posterior, aunque falle, invalida a la anterior.
  Future<bool> hasNewerReact(
    String botId,
    String chatLid,
    String messageId, {
    required int afterId,
  }) async {
    final rows =
        await (_db.select(_db.outbox)..where(
              (o) =>
                  o.botId.equals(botId) &
                  o.chatLid.equals(chatLid) &
                  o.opType.equals('react') &
                  o.id.isBiggerThanValue(afterId),
            ))
            .get();
    for (final r in rows) {
      try {
        final p = jsonDecode(r.payload) as Map<String, dynamic>;
        if (p['messageId'] == messageId) return true;
      } catch (_) {
        // Fila corrupta: ignórala (no cuenta como intención más nueva válida).
      }
    }
    return false;
  }

  /// Operaciones del chat aún vivas (cualquier estado) en orden FIFO, para que
  /// la UI pinte las burbujas pendientes/fallidas mezcladas con los mensajes.
  Stream<List<OutboxRow>> watchForChat(String botId, String chatLid) {
    return (_db.select(_db.outbox)
          ..where((o) => o.botId.equals(botId) & o.chatLid.equals(chatLid))
          ..orderBy([
            (o) => OrderingTerm.asc(o.createdAtMs),
            (o) => OrderingTerm.asc(o.id),
          ]))
        .watch();
  }

  /// Operaciones drenables (`pending`) en orden FIFO global. Las `failed`
  /// (terminales) quedan fuera hasta un reintento manual; las `sending` se
  /// rescatan con [resetOrphanedSending] al arrancar.
  Future<List<OutboxRow>> pending() {
    return (_db.select(_db.outbox)
          ..where((o) => o.state.equals('pending'))
          ..orderBy([
            (o) => OrderingTerm.asc(o.createdAtMs),
            (o) => OrderingTerm.asc(o.id),
          ]))
        .get();
  }

  Future<void> markSending(int id) => _setState(id, 'sending');

  /// Fallo reintentable: vuelve a `pending`, incrementa el contador y guarda el
  /// tipo de error. Se reintenta en el próximo drain (reconexión o backoff).
  Future<void> markRetry(int id, {required String errorKind}) {
    final nowMs = _nowMs();
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.outbox,
      )..where((o) => o.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(
          state: const Value('pending'),
          errorKind: Value(errorKind),
          retryCount: Value(row.retryCount + 1),
          updatedAtMs: Value(nowMs),
        ),
      );
    });
  }

  /// Fallo TERMINAL: queda `failed`; no se reintenta solo (el contrato no lo
  /// permite o el reintento no cambiaría nada). Sólo un reintento manual lo
  /// revive (lo hace la UI en una rebanada posterior).
  Future<void> markFailedTerminal(int id, {required String errorKind}) {
    final nowMs = _nowMs();
    return (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(
        state: const Value('failed'),
        errorKind: Value(errorKind),
        updatedAtMs: Value(nowMs),
      ),
    );
  }

  /// Confirma un envío: en una sola transacción borra la fila del outbox tras
  /// el éxito. (El mensaje real lo escribe el coordinador en la misma
  /// transacción, vía el upsert monótono de `MessagesDao`.)
  Future<void> deleteById(int id) {
    return (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();
  }

  /// Rescata operaciones huérfanas: una `sending` significa un envío
  /// interrumpido por un cierre/kill a media-POST. Volverlas `pending` permite
  /// reenviarlas; la idempotencia por `clientToken` evita duplicados si el
  /// servidor ya las había aceptado. Devuelve cuántas se rescataron.
  Future<int> resetOrphanedSending() {
    final nowMs = _nowMs();
    return (_db.update(
      _db.outbox,
    )..where((o) => o.state.equals('sending'))).write(
      OutboxCompanion(state: const Value('pending'), updatedAtMs: Value(nowMs)),
    );
  }

  /// Reintento manual (acción del usuario sobre una burbuja fallida): revive la
  /// fila a `pending`, resetea el contador y limpia el error para que el próximo
  /// drain la reenvíe. Reusa el `clientToken` ⇒ idempotente.
  Future<void> retryByToken(String botId, String chatLid, String clientToken) {
    return (_db.update(_db.outbox)..where(
          (o) =>
              o.botId.equals(botId) &
              o.chatLid.equals(chatLid) &
              o.clientToken.equals(clientToken),
        ))
        .write(
          OutboxCompanion(
            state: const Value('pending'),
            retryCount: const Value(0),
            errorKind: const Value(null),
            updatedAtMs: Value(_nowMs()),
          ),
        );
  }

  /// Descarta una escritura encolada (acción del usuario). Si el servidor ya la
  /// había aceptado, el mensaje real se recupera en el próximo refresh/reconnect.
  Future<void> deleteByToken(String botId, String chatLid, String clientToken) {
    return (_db.delete(_db.outbox)..where(
          (o) =>
              o.botId.equals(botId) &
              o.chatLid.equals(chatLid) &
              o.clientToken.equals(clientToken),
        ))
        .go();
  }

  Future<void> _setState(int id, String state) {
    return (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
      OutboxCompanion(state: Value(state), updatedAtMs: Value(_nowMs())),
    );
  }

  int _nowMs() => _now().millisecondsSinceEpoch;
}
