import 'dart:async';

import '../../../core/storage/device_id_provider.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../domain/repositories/notifications_repository.dart';
import '../domain/repositories/push_token_provider.dart';

class PushRegistrationCoordinator {
  PushRegistrationCoordinator({
    required AuthBloc authBloc,
    required NotificationsRepository repository,
    required DeviceIdProvider deviceIds,
    required PushTokenProvider tokens,
  }) : _authBloc = authBloc,
       _repo = repository,
       _deviceIds = deviceIds,
       _tokens = tokens;

  final AuthBloc _authBloc;
  final NotificationsRepository _repo;
  final DeviceIdProvider _deviceIds;
  final PushTokenProvider _tokens;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;
  bool _authenticated = false;

  Future<void> start() async {
    if (_authSub != null) return;
    _authSub = _authBloc.stream.listen((state) {
      unawaited(_handleAuthState(state));
    });
    _tokenSub = _tokens.tokenRefreshes.listen((token) {
      unawaited(_registerToken(token));
    });
    await _handleAuthState(_authBloc.state);
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    _authSub = null;
    _tokenSub = null;
  }

  Future<void> _handleAuthState(AuthState state) async {
    if (state is AuthAuthenticated) {
      _authenticated = true;
      final token = await _tokens.currentToken();
      await _registerToken(token);
      return;
    }
    if (state is AuthUnauthenticated && _authenticated) {
      _authenticated = false;
      final deviceId = await _deviceIds.getOrCreate();
      await _repo.unregisterPushToken(deviceId: deviceId);
    }
  }

  Future<void> _registerToken(String? token) async {
    if (!_authenticated || token == null || token.isEmpty) return;
    final deviceId = await _deviceIds.getOrCreate();
    await _repo.registerPushToken(
      deviceId: deviceId,
      fcmToken: token,
      platform: 'android',
    );
  }
}
