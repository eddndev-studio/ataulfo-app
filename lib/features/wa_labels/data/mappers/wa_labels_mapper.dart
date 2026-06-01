import '../../domain/entities/wa_chat_assoc.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/entities/wa_label_live_event.dart';
import '../../domain/entities/wa_label_mapping.dart';
import '../../domain/entities/wa_msg_assoc.dart';
import '../dto/wa_assoc_dto.dart';
import '../dto/wa_label_dto.dart';
import '../dto/wa_label_event_dto.dart';
import '../dto/wa_mapping_dto.dart';

/// Traduce DTOs del espejo de etiquetas WhatsApp a entidades de dominio.
///
/// Preserva el orden del backend en los listados. El frame SSE plano se
/// despliega a la jerarquía sellada `WaLabelLiveEvent` discriminando por
/// `kind`: un kind desconocido propaga `ArgumentError` fail-loud (drift de
/// contrato) y un kind con campos faltantes propaga `FormatException`; el
/// datasource SSE atrapa ambas y omite el frame sin derribar el stream.
class WaLabelsMapper {
  const WaLabelsMapper._();

  static WaLabel labelToEntity(WaLabelResp r) => WaLabel(
    waLabelId: r.waLabelId,
    name: r.name,
    color: r.color,
    deleted: r.deleted,
  );

  static List<WaLabel> catalogToLabels(WaCatalogResp resp) =>
      resp.items.map(labelToEntity).toList(growable: false);

  static WaChatAssoc chatAssocToEntity(WaChatAssocResp r) =>
      WaChatAssoc(chatLid: r.chatLid, waLabelId: r.waLabelId, labeled: r.labeled);

  static List<WaChatAssoc> chatAssocToEntities(WaChatAssocListResp resp) =>
      resp.items.map(chatAssocToEntity).toList(growable: false);

  static WaMsgAssoc msgAssocToEntity(WaMsgAssocResp r) => WaMsgAssoc(
    chatLid: r.chatLid,
    messageId: r.messageId,
    waLabelId: r.waLabelId,
    labeled: r.labeled,
  );

  static List<WaMsgAssoc> msgAssocToEntities(WaMsgAssocListResp resp) =>
      resp.items.map(msgAssocToEntity).toList(growable: false);

  static WaLabelMapping mappingToEntity(WaMappingResp r) =>
      WaLabelMapping(waLabelId: r.waLabelId, labelId: r.labelId);

  static List<WaLabelMapping> mappingsToEntities(WaMappingListResp resp) =>
      resp.items.map(mappingToEntity).toList(growable: false);

  static WaLabelLiveEvent eventToLive(WaLabelEventResp r) {
    switch (r.kind) {
      case 'EDITED':
        return WaLabelCatalogChanged(
          waLabelId: r.waLabelId,
          name: r.name ?? '',
          color: r.color,
          removed: false,
        );
      case 'REMOVED':
        return WaLabelCatalogChanged(
          waLabelId: r.waLabelId,
          name: r.name ?? '',
          color: r.color,
          removed: true,
        );
      case 'CHAT':
        final chatLid = r.chatLid;
        if (chatLid == null) {
          throw const FormatException('evento CHAT sin chatLid');
        }
        return WaChatLabelChanged(
          waLabelId: r.waLabelId,
          chatLid: chatLid,
          color: r.color,
          labeled: r.labeled,
        );
      case 'MESSAGE':
        final chatLid = r.chatLid;
        final messageId = r.messageId;
        if (chatLid == null || messageId == null) {
          throw const FormatException('evento MESSAGE sin chatLid/messageId');
        }
        return WaMessageLabelChanged(
          waLabelId: r.waLabelId,
          chatLid: chatLid,
          messageId: messageId,
          color: r.color,
          labeled: r.labeled,
        );
      default:
        throw ArgumentError.value(r.kind, 'WaLabelsMapper.eventToLive');
    }
  }
}
