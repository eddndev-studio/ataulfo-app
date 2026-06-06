import '../entities/quick_reply.dart';

/// Puerto de dominio del catálogo de respuestas rápidas WhatsApp Business (S23).
/// SOLO LECTURA y per-bot (WORKER+): el operador no crea/edita respuestas rápidas
/// desde el monitor (eso vive en la app de WhatsApp Business); aquí solo se
/// consultan para ofrecerlas en el composer.
abstract interface class QuickRepliesRepository {
  /// Catálogo espejado del bot, incluidos tombstones (`deleted:true`). Lista
  /// vacía es válida. Lanza `QuickRepliesFailure` tipadas.
  Future<List<QuickReply>> listCatalog(String botId);
}
