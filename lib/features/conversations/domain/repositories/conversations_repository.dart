import '../entities/conversation.dart';

/// Puerto de dominio para Conversaciones (S07 RF#7). Define el verbo que el
/// bloc puede pedir; la implementación vive en `data/`.
abstract interface class ConversationsRepository {
  /// Listado de conversaciones (sesiones) del bot dado, org-scoped por el
  /// backend. Lanza `ConversationsNotFoundFailure` si el bot no existe en la
  /// org activa (404), `ConversationsForbiddenFailure` (403), o las variantes
  /// de red/timeout/server. El bloc traduce a estado de UI.
  Future<List<Conversation>> listForBot(String botId);
}
