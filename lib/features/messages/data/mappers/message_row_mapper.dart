import 'package:drift/drift.dart' show Value;

import '../../../../core/db/app_db.dart';
import '../../domain/entities/message.dart';

/// Traduce entre la entidad de dominio [Message] y la fila drift [MessageRow].
/// Los enums se guardan por su `.name`; `mediaUrl` NO se persiste (firma
/// efímera) y `status` es nulo en INBOUND / monótono en OUTBOUND.
class MessageRowMapper {
  const MessageRowMapper._();

  /// [mediaUrl] re-inyecta la firma efímera viva (no persistida) que el repo
  /// conserva en memoria durante la sesión, para que el visor del hilo pueda
  /// bajar/abrir la media; null offline o en frío (se sirve de la caché en
  /// disco por `mediaRef`).
  static Message rowToEntity(MessageRow r, {String? mediaUrl}) => Message(
    externalId: r.externalId,
    chatLid: r.chatLid,
    senderLid: r.senderLid,
    kind: MessageKind.values.byName(r.kind),
    direction: MessageDirection.values.byName(r.direction),
    type: r.type,
    content: r.content,
    mediaRef: r.mediaRef,
    mediaUrl: mediaUrl,
    quotedId: r.quotedId,
    timestampMs: r.timestampMs,
    status: r.status == null ? null : MessageStatus.values.byName(r.status!),
    editedAtMs: r.editedAtMs,
    revokedAtMs: r.revokedAtMs,
    aiRunId: r.aiRunId ?? '',
  );

  static MessagesCompanion toCompanion(
    String botId,
    Message m, {
    required int syncedAtMs,
  }) => MessagesCompanion.insert(
    botId: botId,
    externalId: m.externalId,
    chatLid: m.chatLid,
    senderLid: m.senderLid,
    kind: m.kind.name,
    direction: m.direction.name,
    type: m.type,
    content: m.content,
    timestampMs: m.timestampMs,
    syncedAtMs: syncedAtMs,
    mediaRef: Value(m.mediaRef),
    quotedId: Value(m.quotedId),
    status: Value(m.status?.name),
    editedAtMs: Value(m.editedAtMs),
    revokedAtMs: Value(m.revokedAtMs),
    // '' de dominio ⇒ NULL en la fila (la columna es aditiva y NULL = sin
    // corrida, igual que las filas previas a la migración).
    aiRunId: Value(m.aiRunId.isEmpty ? null : m.aiRunId),
  );
}
