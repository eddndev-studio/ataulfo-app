import 'package:drift/drift.dart';

// Tablas del almacén local (SQLite vía drift): espejo offline del núcleo
// conversacional y única fuente de verdad de la UI. Las conversaciones llevan
// `orgId` además de `botId`: la Bandeja puede cambiar de organización mientras
// una purga asíncrona sigue en vuelo y nunca debe observar filas del tenant
// anterior. Las marcas de tiempo se guardan como epoch en milisegundos (int),
// uniforme con el contrato del wire; los enums de dominio se guardan por su
// `.name`. El nombre de la fila generada lleva sufijo `Row` para no chocar con
// las entidades de dominio (`Conversation`, `Message`).
//
// Al cambiar cualquier tabla aquí, sube `schemaVersion` en app_db.dart Y añade
// el paso de migración incremental en `onUpgrade`: drift sólo migra si la
// versión cambia, y el paso debe conservar el outbox (escrituras sin
// sincronizar). Un cambio de tabla sin subir versión deja a un dispositivo con
// la DB vieja en el esquema previo y revienta en runtime ("no such column").

/// Conversaciones de la bandeja. PK `(botId, chatLid)` = invariante I-S1.
/// `lastMessage*` es una proyección plana del último mensaje (los cuatro campos
/// viajan juntos: todos nulos cuando la conversación no tiene mensajes).
@DataClassName('ConversationRow')
@TableIndex(
  name: 'idx_conversations_inbox',
  columns: {#orgId, #isPinned, #lastMessageTimestampMs, #botId, #chatLid},
)
class Conversations extends Table {
  TextColumn get orgId => text()();
  TextColumn get botId => text()();
  TextColumn get chatLid => text()();
  TextColumn get kind => text()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMarkedUnread =>
      boolean().withDefault(const Constant(false))();
  IntColumn get mutedUntilMs => integer().nullable()();
  TextColumn get displayName => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get lastMessagePreview => text().nullable()();
  TextColumn get lastMessageType => text().nullable()();
  TextColumn get lastMessageDirection => text().nullable()();
  IntColumn get lastMessageTimestampMs => integer().nullable()();
  BoolColumn get needsAttention =>
      boolean().withDefault(const Constant(false))();
  TextColumn get assistantId => text()();
  TextColumn get assistantName => text()();
  TextColumn get channelName => text()();
  TextColumn get channelType => text()();
  TextColumn get channelIdentifier => text().nullable()();
  TextColumn get labelsJson => text()();
  IntColumn get syncedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {botId, chatLid};
}

/// Mensajes de los hilos. PK `(botId, externalId)` = invariante I-M1: el
/// `externalId` (wamid) es único por bot, así que el eco del SSE y la cola HTTP
/// se deduplican por upsert. No se persiste `mediaUrl` (firma efímera): el repo
/// guarda la firma viva del fetch HTTP/SSE en una caché de sesión en memoria y la
/// re-inyecta al emitir el hilo; offline o en frío es null y el visor sirve la
/// media de la caché en disco por `mediaRef` (referencia opaca estable). `status`
/// es nulo en INBOUND y monótono en OUTBOUND (SENT<DELIVERED<READ, FAILED terminal).
@DataClassName('MessageRow')
@TableIndex(
  name: 'idx_messages_thread',
  columns: {#botId, #chatLid, #timestampMs, #externalId},
)
@TableIndex(name: 'idx_messages_status', columns: {#botId, #chatLid, #status})
class Messages extends Table {
  TextColumn get botId => text()();
  TextColumn get externalId => text()();
  TextColumn get chatLid => text()();
  TextColumn get senderLid => text()();
  TextColumn get kind => text()();
  TextColumn get direction => text()();
  TextColumn get type => text()();
  TextColumn get content => text()();
  TextColumn get mediaRef => text().nullable()();
  TextColumn get quotedId => text().nullable()();
  IntColumn get timestampMs => integer()();
  TextColumn get status => text().nullable()();
  IntColumn get syncedAtMs => integer()();

  /// Marcadores de corrección (S25): editado / revocado. Nullable ⇒ la
  /// migración es aditiva (los rows previos quedan intactos).
  IntColumn get editedAtMs => integer().nullable()();
  IntColumn get revokedAtMs => integer().nullable()();

  /// Corrida de IA que produjo el OUTBOUND (La Traza F0). NULL = ninguna ('' en
  /// dominio). Nullable ⇒ migración aditiva; se persiste para que el badge de
  /// IA sobreviva al round-trip local (la UI observa la DB, no la red).
  TextColumn get aiRunId => text().nullable()();

  @override
  Set<Column> get primaryKey => {botId, externalId};
}

/// Cursor de sincronización por hilo. Persiste el último punto consumido
/// `(lastTimestampMs, lastExternalId)` para el delta al reconectar y el cursor
/// opaco más viejo (`oldestCursor`) para reanudar el backfill histórico.
/// `reachedStart` marca que no hay más histórico viejo que traer.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get botId => text()();
  TextColumn get chatLid => text()();
  IntColumn get lastTimestampMs => integer().nullable()();
  TextColumn get lastExternalId => text().nullable()();
  TextColumn get oldestCursor => text().nullable()();
  BoolColumn get reachedStart => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {botId, chatLid};
}

/// Cola de escrituras pendientes (durables y offline). FIFO por `createdAtMs`
/// dentro de cada `chatLid`. `clientToken` da idempotencia al reenviar;
/// `externalId` se rellena al confirmar el envío. `state` ∈
/// {pending, sending, failed}. `opType` ∈ {`send_message`, `mark_read`,
/// `react`}: el coordinador los drena por tipo; cualquier otro lo marca `failed`.
@DataClassName('OutboxRow')
@TableIndex(name: 'idx_outbox_fifo', columns: {#botId, #chatLid, #createdAtMs})
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get botId => text()();
  TextColumn get chatLid => text()();
  TextColumn get opType => text()();
  TextColumn get clientToken => text().nullable()();
  TextColumn get payload => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get externalId => text().nullable()();
  TextColumn get errorKind => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
}
