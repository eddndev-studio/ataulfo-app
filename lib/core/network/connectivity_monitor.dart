/// Señal **proactiva** de conectividad de red. `true` = hay un enlace de red.
///
/// Complementa, no reemplaza, la detección **reactiva** de errores de red de
/// Dio (`DioExceptionType.connectionError` → `*NetworkFailure`): connectivity
/// reporta si EXISTE un enlace, no si hay internet realmente alcanzable. Juntas,
/// la señal proactiva dirige el banner y el drain del outbox, y los errores de
/// Dio cubren el caso "enlazado pero sin internet".
abstract interface class ConnectivityMonitor {
  /// Estado actual, de una sola lectura.
  Future<bool> isOnline();

  /// Cambios de online/offline. No re-emite el mismo valor consecutivo.
  Stream<bool> get onlineChanges;
}
