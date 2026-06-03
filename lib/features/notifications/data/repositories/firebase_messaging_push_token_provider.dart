import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/repositories/push_token_provider.dart';

/// Provider de token FCM real respaldado por firebase_messaging.
///
/// La instancia de [FirebaseMessaging] se inyecta para poder probar el mapeo
/// (token y refrescos) sin depender de los canales de plataforma ni de un
/// device con Google Play Services.
class FirebaseMessagingPushTokenProvider implements PushTokenProvider {
  const FirebaseMessagingPushTokenProvider(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;
}
