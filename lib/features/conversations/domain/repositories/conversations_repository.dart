import '../entities/conversation.dart';

/// Puerto de dominio para Conversaciones (S07 RF#7). La DB local es la fuente
/// de verdad de la UI: el bloc **observa** [watchForBot] y dispara [refresh]
/// para traer el snapshot del backend y escribirlo (write-through). Offline, el
/// watch sigue sirviendo la última caché.
abstract interface class ConversationsRepository {
  /// Bandeja del bot observada desde la DB local (recientes primero). Emite al
  /// abrir con lo cacheado y de nuevo en cada escritura (refresh, realtime).
  Stream<List<Conversation>> watchForBot(String botId);

  /// Trae la bandeja del backend (org-scoped) y la escribe en la DB local. El
  /// `watch` emite el resultado. Lanza `ConversationsFailure` tipada (404 bot
  /// ajeno/inexistente, 403, red/timeout/server) que el bloc traduce a UI; si
  /// falla por red, la caché local permanece intacta.
  Future<void> refresh(String botId);
}
