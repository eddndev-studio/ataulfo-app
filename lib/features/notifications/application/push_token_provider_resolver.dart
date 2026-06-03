import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/repositories/firebase_messaging_push_token_provider.dart';
import '../data/repositories/noop_push_token_provider.dart';
import '../domain/repositories/push_token_provider.dart';

/// Decide qué [PushTokenProvider] usar según la plataforma, aislando del
/// bootstrap tanto la selección como la degradación elegante para poder
/// probarlas sin un device ni canales de plataforma.
///
/// Solo Android usa el transporte FCM real: inicializa Firebase, solicita el
/// permiso de notificaciones (best-effort) y devuelve el provider real. Si
/// Firebase no inicializa (Google Play Services ausente, config inválida), cae
/// a noop en vez de tumbar el arranque. El resto de plataformas (desktop/web,
/// donde firebase_core no aplica) usan noop directamente.
///
/// `initFirebase` y `messaging` se inyectan solo para los tests; en producción
/// usan `Firebase.initializeApp` y `FirebaseMessaging.instance`.
class PushTokenProviderResolver {
  PushTokenProviderResolver({
    required this.isAndroid,
    Future<void> Function()? initFirebase,
    FirebaseMessaging Function()? messaging,
  }) : _initFirebase = initFirebase ?? _defaultInit,
       _messaging = messaging ?? _defaultMessaging;

  final bool isAndroid;
  final Future<void> Function() _initFirebase;
  final FirebaseMessaging Function() _messaging;

  static Future<void> _defaultInit() => Firebase.initializeApp();

  static FirebaseMessaging _defaultMessaging() => FirebaseMessaging.instance;

  Future<PushTokenProvider> resolve() async {
    if (!isAndroid) return const NoopPushTokenProvider();
    try {
      await _initFirebase();
      final messaging = _messaging();
      // Fire-and-forget: el diálogo de permiso (Android 13+) no debe bloquear el
      // arranque ni el primer frame a la espera de la respuesta del usuario.
      unawaited(_requestNotificationPermission(messaging));
      return FirebaseMessagingPushTokenProvider(messaging);
    } catch (_) {
      // Sin Firebase no hay push, pero el arranque no debe caer: noop.
      return const NoopPushTokenProvider();
    }
  }

  Future<void> _requestNotificationPermission(
    FirebaseMessaging messaging,
  ) async {
    try {
      await messaging.requestPermission();
    } catch (_) {
      // Best-effort: el token se obtiene y registra aunque el permiso de
      // notificaciones falle o se rechace (solo afecta la visualización).
    }
  }
}
