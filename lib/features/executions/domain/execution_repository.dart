import 'entities/execution.dart';

/// Puerto de dominio del historial de ejecuciones de un chat (ADMIN+ en el
/// backend). El endpoint per-chat devuelve la lista completa SIN paginación.
abstract interface class ExecutionRepository {
  /// `GET /sessions/:botId/:chatLid/executions`. Lista vacía es válida.
  /// Lanza `ExecutionFailure` tipadas.
  Future<List<Execution>> listBySession({
    required String botId,
    required String chatLid,
  });
}
