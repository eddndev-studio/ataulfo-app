import '../entities/runnable_flow.dart';

/// Puerto de dominio del arranque manual de flujos (S11). El cubit del chat
/// pide la lista de flujos corribles del bot y arranca el elegido sobre la
/// conversación abierta. La implementación vive en `data/`.
abstract interface class FlowRunRepository {
  /// Flujos ACTIVOS del bot corribles desde el chat (`GET /sessions/:botId/
  /// flows`). Lista vacía es válida. Lanza `FlowRunFailure` tipadas.
  Future<List<RunnableFlow>> listRunnable(String botId);

  /// Arranca el flujo `flowId` sobre el chat (`POST /sessions/:botId/:chatLid/
  /// flows/:flowId/run`). Devuelve el `executionId`. Lanza
  /// `FlowRunBlockedFailure` (409 con razón de gate), `FlowRunPausedFailure`
  /// (423), `FlowRunNotFoundFailure` (404) y las variantes de red/server.
  Future<String> run({
    required String botId,
    required String chatLid,
    required String flowId,
  });
}
