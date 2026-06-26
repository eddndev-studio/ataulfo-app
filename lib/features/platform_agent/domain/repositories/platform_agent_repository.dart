import '../entities/pa_conversation.dart';
import '../entities/pa_message.dart';
import '../entities/pa_models.dart';
import '../entities/pa_progress.dart';

/// Puerto del chat con el asistente de plataforma (org-scoped). El POST de
/// mensaje es SÍNCRONO: corre el turno completo del motor y devuelve el
/// assistant final. Los fallos viajan como `PaFailure`.
abstract interface class PlatformAgentRepository {
  Future<PaConversation> createConversation({String title});

  /// Renombra un hilo; devuelve el hilo actualizado.
  Future<PaConversation> renameConversation(String id, String title);

  /// Borra un hilo (y sus mensajes).
  Future<void> deleteConversation(String id);

  /// Hilos del operador en la org activa, DESC por updatedAt.
  Future<List<PaConversation>> listConversations();

  /// Página DESC del historial; cursor vacío ⇒ primera página.
  Future<PaMessagesPage> listMessages({
    required String conversationId,
    String cursor,
    int limit,
  });

  /// Corre un turno: persiste el user message y devuelve el assistant final.
  /// `model` null/vacío ⇒ el turno corre con el modelo default de la plataforma.
  Future<PaMessage> sendMessage({
    required String conversationId,
    required String content,
    String? model,
  });

  /// Allowlist de modelos + default de la plataforma (best-effort: el caller
  /// oculta el selector ante cualquier fallo).
  Future<PaModels> listModels();
}

/// Puerto del stream de progreso del turno (SSE). Una suscripción por hilo;
/// el stream se reconecta solo y emite hasta que el caller lo cancele.
abstract interface class PlatformAgentEvents {
  Stream<PaProgressEvent> progress(String conversationId);
}
