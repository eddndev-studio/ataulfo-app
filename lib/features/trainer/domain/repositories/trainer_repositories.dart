import '../entities/preview_item.dart';
import '../entities/trainer_conversation.dart';
import '../entities/trainer_message.dart';
import '../entities/workspace_doc.dart';

/// Puertos de dominio de la superficie del entrenador. Tres repositorios
/// (workspace / hilos / preview) en un archivo: comparten feature, fallos
/// y ciclo de vida de DI — separarlos en archivos no separa nada real.
abstract interface class WorkspaceRepository {
  Future<List<WorkspaceDoc>> listDocs({required String templateId});
  Future<WorkspaceDoc> getDoc({
    required String templateId,
    required String name,
  });
  Future<WorkspaceDoc> createDoc({
    required String templateId,
    required String name,
    required String content,
  });
  Future<WorkspaceDoc> updateDoc({
    required String templateId,
    required String name,
    required String content,
    required int version,
  });
  Future<void> deleteDoc({
    required String templateId,
    required String name,
    required int version,
  });
}

abstract interface class TrainerRepository {
  Future<TrainerConversation> createConversation({
    required String templateId,
    String title,
  });
  Future<List<TrainerConversation>> listConversations({
    required String templateId,
  });
  Future<TrainerMessagesPage> listMessages({
    required String templateId,
    required String conversationId,
    String cursor,
    int limit,
  });
  Future<TrainerMessage> sendMessage({
    required String templateId,
    required String conversationId,
    required String content,
  });
}

abstract interface class PreviewRepository {
  Future<PreviewTurn> sendMessage({
    required String templateId,
    required String content,
  });
  Future<List<PreviewItem>> transcript({required String templateId});
  Future<void> reset({required String templateId});
}
