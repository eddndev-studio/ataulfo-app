import '../../../conversations/domain/entities/conversation.dart';
import '../../domain/entities/wa_chat_assoc.dart';
import '../../domain/entities/wa_label.dart';
import '../../domain/entities/wa_label_live_event.dart';
import '../../domain/entities/wa_label_mapping.dart';
import '../../domain/entities/wa_msg_assoc.dart';
import '../../domain/repositories/wa_labels_repository.dart';
import '../datasources/wa_assoc_datasource.dart';
import '../datasources/wa_catalog_datasource.dart';
import '../datasources/wa_label_events_datasource.dart';
import '../datasources/wa_mapping_datasource.dart';

/// Implementación que compone los datasources por sub-recurso. Delegate puro:
/// sin cache local en esta capa (cuando aterrice RFC-0001 orquestará verdad
/// local vs. remota). Aislar los datasources por sub-recurso (catálogo /
/// asociaciones / mapeo / realtime) mantiene cada uno bajo SRP; esta clase es
/// la cara única que consume el bloc.
class WaLabelsRepositoryImpl implements WaLabelsRepository {
  WaLabelsRepositoryImpl({
    required WaCatalogDatasource catalog,
    required WaAssocDatasource assoc,
    required WaMappingDatasource mapping,
    required WaLabelEventsDatasource events,
  }) : _catalog = catalog,
       _assoc = assoc,
       _mapping = mapping,
       _events = events;

  final WaCatalogDatasource _catalog;
  final WaAssocDatasource _assoc;
  final WaMappingDatasource _mapping;
  final WaLabelEventsDatasource _events;

  @override
  Future<List<WaLabel>> listCatalog(String botId) =>
      _catalog.listCatalog(botId);

  @override
  Future<WaLabel> createLabel({
    required String botId,
    required String name,
    required int color,
  }) => _catalog.createLabel(botId: botId, name: name, color: color);

  @override
  Future<WaLabel> updateLabel({
    required String botId,
    required String waLabelId,
    required String name,
    required int color,
  }) => _catalog.updateLabel(
    botId: botId,
    waLabelId: waLabelId,
    name: name,
    color: color,
  );

  @override
  Future<void> deleteLabel({
    required String botId,
    required String waLabelId,
  }) => _catalog.deleteLabel(botId: botId, waLabelId: waLabelId);

  @override
  Stream<WaLabelLiveEvent> liveEvents(String botId) =>
      _events.liveEvents(botId);

  @override
  Future<List<WaChatAssoc>> listChatAssocs(String botId) =>
      _assoc.listChatAssocs(botId);

  @override
  Future<List<WaMsgAssoc>> listMsgAssocs(String botId) =>
      _assoc.listMsgAssocs(botId);

  @override
  Future<void> labelChat({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required bool labeled,
  }) => _assoc.labelChat(
    botId: botId,
    waLabelId: waLabelId,
    chatLid: chatLid,
    kind: kind,
    labeled: labeled,
  );

  @override
  Future<void> labelMessage({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required String messageId,
    required bool labeled,
  }) => _assoc.labelMessage(
    botId: botId,
    waLabelId: waLabelId,
    chatLid: chatLid,
    kind: kind,
    messageId: messageId,
    labeled: labeled,
  );

  @override
  Future<List<WaLabelMapping>> listMappings(String botId) =>
      _mapping.listMappings(botId);

  @override
  Future<WaLabelMapping> setMapping({
    required String botId,
    required String waLabelId,
    required String labelId,
  }) =>
      _mapping.setMapping(botId: botId, waLabelId: waLabelId, labelId: labelId);

  @override
  Future<void> deleteMapping({
    required String botId,
    required String waLabelId,
  }) => _mapping.deleteMapping(botId: botId, waLabelId: waLabelId);
}
