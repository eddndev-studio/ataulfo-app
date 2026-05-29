import '../../domain/entities/conversation.dart';
import '../dto/conversation_dto.dart';

/// Traduce el DTO del wire S07 a la entidad de dominio. Pura: cualquier
/// llamador (datasource, test, futura cache) la compone sin estado.
///
/// `kind` pasa por `ConversationKind.fromWire` (fail-loud ante drift). El
/// `muted_until` RFC3339 se parsea a `DateTime` (UTC del wire); `null` queda
/// `null`. Un `muted_until` malformado lanza `FormatException` — el datasource
/// lo colapsa a `UnknownConversationsFailure` (contrato roto, no accionable).
class ConversationsMapper {
  const ConversationsMapper._();

  static Conversation respToEntity(ConversationResp resp) => Conversation(
    chatLid: resp.chatLid,
    kind: ConversationKind.fromWire(resp.kind),
    phone: resp.phone,
    isArchived: resp.isArchived,
    isPinned: resp.isPinned,
    isMarkedUnread: resp.isMarkedUnread,
    mutedUntil: resp.mutedUntil == null
        ? null
        : DateTime.parse(resp.mutedUntil!),
  );
}
