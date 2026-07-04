import '../entities/message.dart';
import '../entities/outbox_entry.dart';
import '../entities/thread_live_event.dart';

/// Puerto de dominio del hilo de mensajes (S09 RF#5 + realtime S15). DB-as-source:
/// el bloc **observa** [watchThread] (la DB local) y la red la alimenta
/// write-through — [refreshThread] (cola reciente), [loadOlder] (histórico por
/// cursor), [applyLiveMessage]/[applyStatus] (SSE). El envío y los recibos
/// (send/markRead/react) y el flujo en vivo (live) conservan su forma.
abstract interface class MessagesRepository {
  /// Hilo observado desde la DB local en orden ascendente (viejo→nuevo). Emite
  /// al abrir con lo cacheado y de nuevo en cada escritura. Los errores no
  /// tipados se traducen a `MessagesFailure`.
  Stream<List<Message>> watchThread(String botId, String chatLid);

  /// Cursor de backfill persistido (siembra `hasMore` al reabrir, también
  /// offline); `null` = inicio del hilo alcanzado o aún sin sincronizar.
  Future<String?> threadCursor(String botId, String chatLid);

  /// Trae la cola más reciente del backend, la escribe (write-through) y, si
  /// `resetCursor`, persiste el cursor de backfill (apertura inicial). En el
  /// reconcile tras reconexión se pasa `resetCursor: false` para no reubicar el
  /// punto de paginación del usuario. Devuelve el cursor de backfill (`null` = no
  /// hay más viejo). Lanza `MessagesFailure`; si falla por red la caché permanece.
  Future<String?> refreshThread(
    String botId,
    String chatLid, {
    bool resetCursor = true,
  });

  /// Trae el tramo inmediatamente más viejo (por el cursor persistido), lo
  /// escribe y actualiza el cursor. Devuelve el nuevo cursor (`null` = inicio
  /// alcanzado). No-op (devuelve `null`) si ya no hay más viejo.
  Future<String?> loadOlder(String botId, String chatLid);

  /// Escribe un mensaje del flujo en vivo en la DB (write-through; status
  /// monótono). Best-effort: un fallo de escritura lo recupera el reconcile.
  Future<void> applyLiveMessage(String botId, Message message);

  /// Aplica un recibo de estado en vivo a un mensaje local (monótono).
  /// Best-effort.
  Future<void> applyStatus(
    String botId,
    String externalId,
    MessageStatus status,
  );

  /// Encola un envío del operador (S09) en el outbox durable y dispara el drain.
  /// `clientToken` es la idempotency-key; `type` es `text`/`image` (con
  /// `mediaRef` para imagen, `content` opcional como caption). NO bloquea por la
  /// red: la burbuja pendiente aparece vía [watchPending] y el coordinador
  /// reconcilia el mensaje real contra la DB al confirmar el envío.
  Future<void> send(
    String botId,
    String chatLid, {
    required String clientToken,
    required String type,
    String content,
    String? mediaRef,
    List<int>? waveform,
    String? quotedId,
  });

  /// Escrituras encoladas del chat (burbujas "enviando/fallido"), observadas
  /// desde el outbox durable en orden FIFO. Sobreviven a un reinicio de la app.
  Stream<List<OutboxEntry>> watchPending(String botId, String chatLid);

  /// Reintento manual de un envío fallido (por `clientToken`): lo revive y
  /// dispara el drain. Reusa el token ⇒ idempotente.
  Future<void> retrySend(String botId, String chatLid, String clientToken);

  /// Descarta un envío encolado (por `clientToken`).
  Future<void> discardSend(String botId, String chatLid, String clientToken);

  /// Encola un mark-read durable de los INBOUND del chat (S09): todos, o hasta
  /// `upToMessageId` inclusive. NO bloquea por la red: se reintenta al
  /// reconectar; coalesce los pendientes del chat (idempotente).
  Future<void> markRead(String botId, String chatLid, {String? upToMessageId});

  /// Encola una reacción durable al mensaje `messageId` con `emoji` (S09);
  /// `emoji` vacío quita la reacción. Se reintenta al reconectar; coalesce por
  /// mensaje (gana la última intención).
  Future<void> react(
    String botId,
    String chatLid, {
    required String messageId,
    required String emoji,
  });

  /// Corrige el texto de un SALIENTE del negocio (espejo del edit de
  /// WhatsApp: tipo texto, ≤15 min; el servidor es autoritativo y responde
  /// 409 si ya no es editable). Camino DIRECTO, sin outbox: encolar una
  /// corrección offline podría empujarla fuera de la ventana — mejor fallar
  /// honesto. En éxito aplica write-through el Message devuelto (contenido
  /// nuevo + `editedAtMs`), así el hilo repinta al instante.
  Future<void> editMessage(
    String botId,
    String chatLid, {
    required String messageId,
    required String newText,
  });

  /// Elimina PARA TODOS un saliente del negocio. Camino directo (como
  /// [editMessage]); en éxito sella `revokedAtMs` local write-through.
  Future<void> deleteMessage(
    String botId,
    String chatLid, {
    required String messageId,
  });

  /// Vacía el historial completo del chat (S07 RF#10). Servidor-primero: el
  /// DELETE es autoritativo; en éxito la copia local del hilo se borra
  /// write-through y la bandeja proyecta el chat sin actividad. En fallo, lo
  /// local queda intacto (el hilo jamás miente un vaciado que no ocurrió).
  Future<void> clearHistory(String botId, String chatLid);

  /// Stream de eventos en vivo del bot (SSE S15: `message.inbound` +
  /// `message.outbound`). El filtrado por conversación lo hace el consumidor.
  /// Perdurable: se reconecta solo; emite `LiveMessage` por mensaje,
  /// `LiveStatus` por recibo y `LiveReconnected` al reconectar (señal para
  /// reconciliar contra la verdad HTTP).
  Stream<ThreadLiveEvent> live(String botId);
}
