import 'package:dio/dio.dart';

import '../../../conversations/domain/entities/conversation.dart';
import '../../domain/entities/wa_chat_assoc.dart';
import '../../domain/entities/wa_msg_assoc.dart';
import '../../domain/failures/wa_labels_failure.dart';
import '../dto/wa_assoc_dto.dart';
import '../mappers/wa_labels_mapper.dart';
import 'wa_labels_errors.dart';

/// Puerto de datos de las asociaciones etiqueta-WhatsApp ↔ chat/mensaje (S21):
/// lectura del espejo + asociar/desasociar empujando al cliente WhatsApp.
///
/// El `kind` (DM/GROUP) viaja en el body porque determina el server del JID
/// destino y no es deducible del `chatLid` pelado — se reusa `ConversationKind`
/// (el mismo DM/GROUP de S07). El `chatLid` se percent-encodea en el path (los
/// grupos llevan `@`).
abstract interface class WaAssocDatasource {
  /// `GET /bots/{botId}/wa-labels/chats`. Asociaciones etiqueta↔chat.
  Future<List<WaChatAssoc>> listChatAssocs(String botId);

  /// `GET /bots/{botId}/wa-labels/messages`. Asociaciones etiqueta↔mensaje.
  Future<List<WaMsgAssoc>> listMsgAssocs(String botId);

  /// `PUT /bots/{botId}/wa-labels/{waLabelId}/chats/{chatLid}` body
  /// `{kind, labeled}`. `labeled:false` desasocia. Empuja a WhatsApp (push
  /// failures: 422/409/502).
  Future<void> labelChat({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required bool labeled,
  });

  /// `PUT /bots/{botId}/wa-labels/{waLabelId}/messages` body
  /// `{chatLid, kind, messageId, labeled}`. El `messageId` (wamid) va en el body
  /// (no es path-safe). Empuja a WhatsApp.
  Future<void> labelMessage({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required String messageId,
    required bool labeled,
  });
}

class DioWaAssocDatasource implements WaAssocDatasource {
  DioWaAssocDatasource(this._dio);

  final Dio _dio;

  @override
  Future<List<WaChatAssoc>> listChatAssocs(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bots/$botId/wa-labels/chats',
      );
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.chatAssocToEntities(
        WaChatAssocListResp.fromJson(body),
      );
    } on WaLabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw WaLabelsErrors.read(e);
    } on FormatException {
      throw const WaLabelsUnknownFailure();
    } on TypeError {
      throw const WaLabelsUnknownFailure();
    }
  }

  @override
  Future<List<WaMsgAssoc>> listMsgAssocs(String botId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/bots/$botId/wa-labels/messages',
      );
      final body = res.data;
      if (body == null) {
        throw const WaLabelsUnknownFailure();
      }
      return WaLabelsMapper.msgAssocToEntities(
        WaMsgAssocListResp.fromJson(body),
      );
    } on WaLabelsFailure {
      rethrow;
    } on DioException catch (e) {
      throw WaLabelsErrors.read(e);
    } on FormatException {
      throw const WaLabelsUnknownFailure();
    } on TypeError {
      throw const WaLabelsUnknownFailure();
    }
  }

  @override
  Future<void> labelChat({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required bool labeled,
  }) async {
    try {
      await _dio.put<void>(
        '/bots/$botId/wa-labels/$waLabelId/chats/${Uri.encodeComponent(chatLid)}',
        data: <String, dynamic>{'kind': _kindToWire(kind), 'labeled': labeled},
      );
    } on DioException catch (e) {
      throw WaLabelsErrors.push(e);
    }
  }

  @override
  Future<void> labelMessage({
    required String botId,
    required String waLabelId,
    required String chatLid,
    required ConversationKind kind,
    required String messageId,
    required bool labeled,
  }) async {
    try {
      await _dio.put<void>(
        '/bots/$botId/wa-labels/$waLabelId/messages',
        data: <String, dynamic>{
          'chatLid': chatLid,
          'kind': _kindToWire(kind),
          'messageId': messageId,
          'labeled': labeled,
        },
      );
    } on DioException catch (e) {
      throw WaLabelsErrors.push(e);
    }
  }

  static String _kindToWire(ConversationKind k) =>
      k == ConversationKind.group ? 'GROUP' : 'DM';
}
