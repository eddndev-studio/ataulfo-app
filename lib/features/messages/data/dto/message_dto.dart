/// DTOs del wire S09 (`ataulfo-go/internal/adapters/httpmessages/dto.go`,
/// `GET /sessions/:botId/:chatLid/messages`). Mantiene los nombres **camelCase**
/// del wire (este adaptador NO usa snake_case, a diferencia de httpsessions) y
/// los tipos crudos; la traducción a dominio vive en `MessagesMapper`.
///
/// `mediaRef`, `mediaUrl`, `quotedId` y `status` son nullable porque el handler
/// usa `omitempty`: un mensaje sin media no manda `mediaRef`/`mediaUrl`, uno sin
/// quote no manda `quotedId`, y los INBOUND no llevan `status`. `content` NO es
/// omitempty (siempre presente, puede ser ""). `mediaUrl` es la URL firmada
/// lista para consumir (el cliente no firma); ausente cuando no hay media o el
/// backend no pudo firmar (p. ej. R2 sin configurar).
class MessageResp {
  const MessageResp({
    required this.externalId,
    required this.chatLid,
    required this.senderLid,
    required this.kind,
    required this.direction,
    required this.type,
    required this.content,
    required this.timestampMs,
    required this.mediaRef,
    required this.quotedId,
    required this.status,
    this.mediaUrl,
    this.editedAtMs,
    this.revokedAtMs,
  });

  factory MessageResp.fromJson(Map<String, dynamic> json) {
    final externalId = json['externalId'];
    final chatLid = json['chatLid'];
    final senderLid = json['senderLid'];
    final kind = json['kind'];
    final direction = json['direction'];
    final type = json['type'];
    final content = json['content'];
    final timestampMs = json['timestampMs'];
    final mediaRef = json['mediaRef'];
    final mediaUrl = json['mediaUrl'];
    final quotedId = json['quotedId'];
    final status = json['status'];
    // Claves aditivas de corrección (omitempty): ausentes ⇒ null (intacto).
    final editedAtMs = json['editedAtMs'];
    final revokedAtMs = json['revokedAtMs'];
    if (externalId is! String ||
        chatLid is! String ||
        senderLid is! String ||
        kind is! String ||
        direction is! String ||
        type is! String ||
        content is! String) {
      throw const FormatException('messageResp: clave obligatoria ausente');
    }
    if (timestampMs is! int) {
      throw const FormatException('messageResp: timestampMs no es int');
    }
    if (mediaRef != null && mediaRef is! String) {
      throw const FormatException('messageResp: mediaRef no es String ni null');
    }
    if (mediaUrl != null && mediaUrl is! String) {
      throw const FormatException('messageResp: mediaUrl no es String ni null');
    }
    if (quotedId != null && quotedId is! String) {
      throw const FormatException('messageResp: quotedId no es String ni null');
    }
    if (status != null && status is! String) {
      throw const FormatException('messageResp: status no es String ni null');
    }
    if (editedAtMs != null && editedAtMs is! int) {
      throw const FormatException('messageResp: editedAtMs no es int ni null');
    }
    if (revokedAtMs != null && revokedAtMs is! int) {
      throw const FormatException('messageResp: revokedAtMs no es int ni null');
    }
    return MessageResp(
      externalId: externalId,
      chatLid: chatLid,
      senderLid: senderLid,
      kind: kind,
      direction: direction,
      type: type,
      content: content,
      timestampMs: timestampMs,
      mediaRef: mediaRef as String?,
      mediaUrl: mediaUrl as String?,
      quotedId: quotedId as String?,
      status: status as String?,
      editedAtMs: editedAtMs as int?,
      revokedAtMs: revokedAtMs as int?,
    );
  }

  final String externalId;
  final String chatLid;
  final String senderLid;
  final String kind;
  final String direction;
  final String type;
  final String content;
  final int timestampMs;
  final String? mediaRef;

  /// URL firmada lista para consumir, o `null` (sin media / sin firmar).
  final String? mediaUrl;
  final String? quotedId;
  final String? status;
  final int? editedAtMs;
  final int? revokedAtMs;
}

/// Página del hilo: `{messages, prevCursor?}`. `messages` siempre presente
/// (array, nunca null); `prevCursor` omitempty (ausente ⇒ inicio del hilo).
class MessageThreadResp {
  const MessageThreadResp({required this.messages, required this.prevCursor});

  factory MessageThreadResp.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'];
    final prevCursor = json['prevCursor'];
    if (messages is! List) {
      throw const FormatException(
        'messageThreadResp: messages ausente o no es lista',
      );
    }
    if (prevCursor != null && prevCursor is! String) {
      throw const FormatException(
        'messageThreadResp: prevCursor no es String ni null',
      );
    }
    return MessageThreadResp(
      messages: messages
          .cast<Map<String, dynamic>>()
          .map(MessageResp.fromJson)
          .toList(growable: false),
      prevCursor: prevCursor as String?,
    );
  }

  final List<MessageResp> messages;
  final String? prevCursor;
}
