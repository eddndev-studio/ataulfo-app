import 'package:flutter/foundation.dart';

import '../../domain/entities/preview_item.dart';
import '../../domain/entities/preview_attachment.dart';
import '../../domain/entities/trainer_attachment.dart';
import '../../domain/entities/trainer_conversation.dart';
import '../../domain/entities/trainer_message.dart';
import '../../domain/entities/trainer_models.dart';
import '../../domain/entities/workspace_doc.dart';
import '../../domain/repositories/trainer_repositories.dart';
import '../datasources/preview_datasource.dart';
import '../datasources/trainer_datasource.dart';
import '../datasources/workspace_datasource.dart';

/// Impls delgadas: el datasource ya tipa fallos y mapea DTO→entidad; el
/// repo existe como costura de DI/testabilidad (mismo criterio que notes).
class WorkspaceRepositoryImpl implements WorkspaceRepository {
  WorkspaceRepositoryImpl({required WorkspaceDatasource datasource})
    : _ds = datasource;

  final WorkspaceDatasource _ds;

  @override
  Future<List<WorkspaceDoc>> listDocs({required String templateId}) =>
      _ds.listDocs(templateId: templateId);

  @override
  Future<WorkspaceDoc> getDoc({
    required String templateId,
    required String name,
  }) => _ds.getDoc(templateId: templateId, name: name);

  @override
  Future<WorkspaceDoc> createDoc({
    required String templateId,
    required String name,
    required String content,
  }) => _ds.createDoc(templateId: templateId, name: name, content: content);

  @override
  Future<WorkspaceDoc> updateDoc({
    required String templateId,
    required String name,
    required String content,
    required int version,
  }) => _ds.updateDoc(
    templateId: templateId,
    name: name,
    content: content,
    version: version,
  );

  @override
  Future<void> deleteDoc({
    required String templateId,
    required String name,
    required int version,
  }) => _ds.deleteDoc(templateId: templateId, name: name, version: version);
}

class TrainerRepositoryImpl implements TrainerRepository {
  TrainerRepositoryImpl({required TrainerDatasource datasource})
    : _ds = datasource;

  final TrainerDatasource _ds;

  @override
  Future<TrainerConversation> createConversation({
    required String templateId,
    String title = '',
  }) => _ds.createConversation(templateId: templateId, title: title);

  @override
  Future<List<TrainerConversation>> listConversations({
    required String templateId,
  }) => _ds.listConversations(templateId: templateId);

  @override
  Future<TrainerMessagesPage> listMessages({
    required String templateId,
    required String conversationId,
    String cursor = '',
    int limit = 0,
  }) => _ds.listMessages(
    templateId: templateId,
    conversationId: conversationId,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<TrainerMessage> sendMessage({
    required String templateId,
    required String conversationId,
    required String content,
    String? model,
    List<String> attachments = const <String>[],
  }) => _ds.sendMessage(
    templateId: templateId,
    conversationId: conversationId,
    content: content,
    model: model,
    attachments: attachments,
  );

  @override
  Future<TrainerAttachment> uploadAttachment({
    required String templateId,
    required Uint8List bytes,
    required String filename,
  }) => _ds.uploadAttachment(
    templateId: templateId,
    bytes: bytes,
    filename: filename,
  );

  @override
  Future<TrainerModels> listModels({required String templateId}) =>
      _ds.listModels(templateId: templateId);

  @override
  void cancelSend() => _ds.cancelInFlight();
}

class PreviewRepositoryImpl implements PreviewRepository {
  PreviewRepositoryImpl({required PreviewDatasource datasource})
    : _ds = datasource;

  final PreviewDatasource _ds;

  @override
  Future<PreviewTurn> sendMessage({
    required String templateId,
    required String content,
    List<PreviewAttachment> attachments = const <PreviewAttachment>[],
  }) => _ds.sendMessage(
    templateId: templateId,
    content: content,
    attachments: attachments,
  );

  @override
  Future<PreviewTranscript> transcript({required String templateId}) =>
      _ds.transcript(templateId: templateId);

  @override
  Future<void> reset({required String templateId}) =>
      _ds.reset(templateId: templateId);
}
