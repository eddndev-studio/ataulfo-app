import '../entities/quick_reply.dart';

/// Puerto de dominio del catálogo de respuestas rápidas WhatsApp Business (S23).
/// SOLO LECTURA y per-bot (WORKER+): el operador no crea/edita respuestas rápidas
/// desde el monitor (eso vive en la app de WhatsApp Business); aquí solo se
/// consultan para ofrecerlas en el composer.
abstract interface class QuickRepliesRepository {
  /// Catálogo espejado del bot, incluidos tombstones (`deleted:true`). Lista
  /// vacía es válida. Lanza `QuickRepliesFailure` tipadas. Revalida siempre
  /// contra el server y refresca la caché de sesión.
  Future<List<QuickReply>> listCatalog(String botId);

  /// Último catálogo cacheado de `botId` en esta sesión, o `null` si nunca se
  /// consultó. Permite sembrar el selector ⚡ al instante al reabrir un hilo —en
  /// vez del "cargando" de varios segundos— y revalidar en silencio.
  ///
  /// `[]` (caché vacía: el bot no tiene respuestas guardadas) es distinto de
  /// `null` (sin caché): el primero se siembra como cargado-vacío, no pendiente.
  List<QuickReply>? cachedCatalog(String botId);

  /// Purga la caché del catálogo (al cerrar sesión) para no servir el catálogo
  /// de una cuenta a la siguiente sin reiniciar la app.
  void invalidate();
}
