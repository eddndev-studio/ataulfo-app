import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_monitor.dart';

/// [ConnectivityMonitor] respaldado por `connectivity_plus`.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// `true` si la lista trae algún enlace distinto de `none` (lista vacía =
  /// sin enlace). Pura y testeable sin el plugin de plataforma.
  static bool isOnlineFrom(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      isOnlineFrom(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(isOnlineFrom).distinct();
}
