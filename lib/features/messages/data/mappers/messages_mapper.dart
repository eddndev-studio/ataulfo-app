import '../../domain/entities/message.dart';
import '../../domain/entities/message_page.dart';
import '../dto/message_dto.dart';

/// Traduce los DTOs del wire S09 a entidades de dominio. Pura: cualquier
/// llamador (datasource, test, futura cache) la compone sin estado.
///
/// `kind`/`direction` pasan por `fromWire` fail-loud; `status` por el
/// `fromWire` tolerante (ausente/vacío→null). Un `kind`/`direction`
/// desconocido lanza `ArgumentError`; el datasource lo colapsa a
/// `UnknownMessagesFailure` (contrato roto, no accionable).
class MessagesMapper {
  const MessagesMapper._();

  static Message respToMessage(MessageResp r) => Message(
    externalId: r.externalId,
    chatLid: r.chatLid,
    senderLid: r.senderLid,
    kind: MessageKind.fromWire(r.kind),
    direction: MessageDirection.fromWire(r.direction),
    type: r.type,
    content: r.content,
    mediaRef: r.mediaRef,
    mediaUrl: r.mediaUrl,
    quotedId: r.quotedId,
    timestampMs: r.timestampMs,
    status: MessageStatus.fromWire(r.status),
    editedAtMs: r.editedAtMs,
    revokedAtMs: r.revokedAtMs,
  );

  static MessagePage respToPage(MessageThreadResp r) => MessagePage(
    messages: r.messages.map(respToMessage).toList(growable: false),
    prevCursor: r.prevCursor,
  );
}
