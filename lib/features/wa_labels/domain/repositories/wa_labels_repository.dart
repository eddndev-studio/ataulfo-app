import '../../../conversations/domain/entities/conversation.dart';
import '../entities/wa_chat_assoc.dart';
import '../entities/wa_label.dart';
import '../entities/wa_label_live_event.dart';
import '../entities/wa_label_mapping.dart';
import '../entities/wa_msg_assoc.dart';

/// Puerto de dominio de la sección de etiquetas WhatsApp (S21). Agrega las tres
/// caras del recurso (catálogo, asociaciones, mapeo) más el realtime, para que
/// el bloc dependa de una sola abstracción. Todo es per-bot (WORKER+).
abstract interface class WaLabelsRepository {
  // --- Catálogo ---------------------------------------------------------------

  /// Catálogo espejado del bot, incluidos tombstones (`deleted:true`). Lista
  /// vacía es válida.
  Future<List<WaLabel>> listCatalog(String botId);

  /// Crea una etiqueta (el servidor asigna el id y empuja a WhatsApp).
  Future<WaLabel> createLabel({
    required String botId,
    required String name,
    required int color,
  });

  /// Edita una etiqueta (empuja a WhatsApp).
  Future<WaLabel> updateLabel({
    required String botId,
    required String waLabelId,
    required String name,
    required int color,
  });

  /// Borra una etiqueta (tombstone; empuja a WhatsApp).
  Future<void> deleteLabel({required String botId, required String waLabelId});

  // --- Realtime ---------------------------------------------------------------

  /// Stream perdurable de cambios `label.wa.*` del bot (reconecta solo; emite
  /// `WaLabelReconnected` al reestablecerse para reconciliar contra el GET).
  Stream<WaLabelLiveEvent> liveEvents(String botId);

  // --- Asociaciones -----------------------------------------------------------

  Future<List<WaChatAssoc>> listChatAssocs(String botId);

  Future<List<WaMsgAssoc>> listMsgAssocs(String botId);

  /// Asocia/desasocia una etiqueta a un chat (empuja a WhatsApp).
  Future<void> labelChat({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required bool labeled,
  });

  /// Asocia/desasocia una etiqueta a un mensaje (empuja a WhatsApp).
  Future<void> labelMessage({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required String messageId,
    required bool labeled,
  });

  // --- Mapeo a Label interno --------------------------------------------------

  Future<List<WaLabelMapping>> listMappings(String botId);

  /// Fija/re-mapea el vínculo a un Label interno (NO empuja a WhatsApp). 422 si
  /// el `labelId` no existe en la org del bot.
  Future<WaLabelMapping> setMapping({
    required String botId,
    required String waLabelId,
    required String labelId,
  });

  /// Quita el vínculo (idempotente; NO empuja a WhatsApp).
  Future<void> deleteMapping({
    required String botId,
    required String waLabelId,
  });
}
