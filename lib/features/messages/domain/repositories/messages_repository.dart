import '../entities/message_page.dart';

/// Puerto de dominio del hilo de mensajes (S09 RF#5). El bloc pide la cola
/// (sin cursor) al abrir y tramos más viejos (con `cursor`) al cargar hacia
/// arriba; la implementación vive en `data/`.
abstract interface class MessagesRepository {
  /// Página del hilo `(botId, chatLid)`. Sin `cursor` ⇒ los mensajes más
  /// recientes; con `cursor` (un `prevCursor` previo) ⇒ el tramo
  /// inmediatamente más viejo. Lanza `MessagesNotFoundFailure` (404, bot
  /// ajeno), `MessagesForbiddenFailure` (403) o las variantes de
  /// red/timeout/server. Un hilo vacío devuelve una página con `messages`
  /// vacía (no es failure).
  Future<MessagePage> thread(
    String botId,
    String chatLid, {
    String? cursor,
    int? limit,
  });
}
