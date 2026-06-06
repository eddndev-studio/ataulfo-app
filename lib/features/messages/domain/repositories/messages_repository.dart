import '../entities/message.dart';
import '../entities/message_page.dart';
import '../entities/thread_live_event.dart';

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

  /// Envía un mensaje del operador (S09). `clientToken` es idempotency-key;
  /// `type` es `text`/`image` (con `mediaRef` para imagen, `content` opcional
  /// como caption). Devuelve el Message persistido. Lanza `MessagesFailure`.
  Future<Message> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content,
    String? mediaRef,
  });

  /// Marca como leídos los INBOUND del chat (S09): todos, o hasta
  /// `upToMessageId` inclusive. Devuelve `markedCount`.
  Future<int> markRead(String botId, String chatLid, {String? upToMessageId});

  /// Reacciona al mensaje `messageId` con `emoji` (S09); `emoji` vacío quita la
  /// reacción previa.
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  });

  /// Stream de eventos en vivo del bot (SSE S15: `message.inbound` +
  /// `message.outbound`). El filtrado por conversación lo hace el consumidor
  /// (el bloc del hilo abierto). Perdurable: se reconecta solo ante caídas;
  /// emite `LiveMessage` por mensaje y `LiveReconnected` al reconectar (señal
  /// para reconciliar contra la verdad HTTP, que sí cubre el tramo del corte).
  Stream<ThreadLiveEvent> live(String botId);
}
