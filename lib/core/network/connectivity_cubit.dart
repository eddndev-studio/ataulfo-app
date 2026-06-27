import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_monitor.dart';

/// Estado de conectividad para la UI (banner) y demás consumidores.
/// `true` = online.
///
/// Arranca **optimista** en `true` y se corrige con el primer chequeo real,
/// para no parpadear "sin conexión" en el arranque mientras llega la lectura
/// inicial. Después sigue los cambios del [ConnectivityMonitor].
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(this._monitor) : super(true) {
    _sub = _monitor.onlineChanges.listen(_set);
    unawaited(_init());
  }

  final ConnectivityMonitor _monitor;
  StreamSubscription<bool>? _sub;

  Future<void> _init() async => _set(await _monitor.isOnline());

  void _set(bool online) {
    if (!isClosed && online != state) emit(online);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
