import '../entities/conversation.dart';
import '../entities/conversations_page.dart';
import '../entities/inbox_live_event.dart';
import '../entities/inbox_query.dart';

abstract interface class ConversationsRepository {
  Stream<List<Conversation>> watchAll();

  /// Consulta una página org-scoped y la persiste por upsert. El valor devuelto
  /// conserva el orden autoritativo del servidor y su cursor opaco.
  Future<ConversationsPage> fetchPage(InboxQuery query);

  Stream<InboxLiveEvent> live();

  /// Proyección optimista para que Atención responda antes del reconcile REST.
  Future<void> markNeedsAttention(String botId, String chatLid);

  /// Se usa ante revocación/403: una caché previa no debe seguir siendo visible.
  Future<void> clearCached();
}
