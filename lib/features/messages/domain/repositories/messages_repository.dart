import '../entities/message.dart';
import '../entities/message_page.dart';

/// Puerto de dominio del hilo de mensajes (S09 RF#5 + realtime S15). El bloc
/// pide la cola (sin cursor) al abrir y tramos más viejos (con `cursor`) al
/// cargar hacia arriba; y se suscribe a `live` para el flujo en vivo. La
/// implementación vive en `data/`.
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

  /// Stream de mensajes en vivo del bot (SSE S15: `message.inbound` +
  /// `message.outbound`). El filtrado por conversación lo hace el consumidor
  /// (el bloc del hilo abierto). Best-effort: errores de transporte cierran el
  /// stream sin derribar el hilo HTTP ya cargado.
  Stream<Message> live(String botId);
}
