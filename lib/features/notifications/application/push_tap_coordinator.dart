import 'dart:async';

import '../../auth/presentation/bloc/auth_bloc.dart';
import 'push_route_resolver.dart';

/// Navega al destino de un push TOCADO (bandeja del sistema o notificación
/// local en foreground). Sin esto, tocar la notificación solo traía la app al
/// frente sin ir a ninguna parte.
///
/// El gate de sesión existe por el cold start: al abrir desde la bandeja con
/// la app muerta, el auth-check todavía corre y el redirect del router
/// mandaría al splash/login tragándose el destino. Se espera el PRIMER estado
/// resuelto: con sesión se navega; sin sesión el tap se descarta (el login no
/// debe heredar deep-links de otra cuenta).
class PushTapCoordinator {
  PushTapCoordinator({
    required AuthBloc authBloc,
    required Stream<Map<String, Object?>> taps,
    required Future<Map<String, Object?>?> Function() initialTap,
    required void Function(String location) navigate,
  }) : _authBloc = authBloc,
       _taps = taps,
       _initialTap = initialTap,
       _navigate = navigate;

  final AuthBloc _authBloc;
  final Stream<Map<String, Object?>> _taps;
  final Future<Map<String, Object?>?> Function() _initialTap;
  final void Function(String location) _navigate;

  StreamSubscription<Map<String, Object?>>? _sub;

  Future<void> start() async {
    if (_sub != null) return;
    _sub = _taps.listen((data) => unawaited(_open(data)));
    final initial = await _initialTap();
    if (initial != null) {
      await _open(initial);
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _open(Map<String, Object?> data) async {
    final route = pushRouteFor(data);
    if (!await _sessionReady()) return;
    _navigate(route);
  }

  /// true si hay (o llega a haber) sesión activa; false si el primer estado
  /// resuelto es sin-sesión. `AuthAuthenticatedNoOrg` cuenta como sin destino:
  /// el selector de organización manda y el deep-link ya no aplica.
  Future<bool> _sessionReady() async {
    final current = _authBloc.state;
    if (current is AuthAuthenticated) return true;
    if (current is! AuthInitial) return false;
    final resolved = await _authBloc.stream.firstWhere(
      (s) => s is! AuthInitial,
      orElse: () => _authBloc.state,
    );
    return resolved is AuthAuthenticated;
  }
}
