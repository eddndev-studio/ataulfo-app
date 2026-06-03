import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/repositories/firebase_messaging_push_token_provider.dart';
import '../data/repositories/flutter_local_notifier.dart';
import '../domain/repositories/push_token_provider.dart';
import 'foreground_push_presenter.dart';

/// Handler de mensajes en background. El SO ya pinta en la bandeja los mensajes
/// de notificación cuando la app no está en foreground; para el MVP no hace
/// falta trabajo extra aquí (el procesamiento de data-messages en background es
/// trabajo futuro). Debe ser top-level y anotado para el entry-point de la VM.
@pragma('vm:entry-point')
Future<void> pushFirebaseBackgroundHandler(RemoteMessage message) async {}

/// Cablea la visualización de push cuando el transporte real está activo
/// (Android con Firebase inicializado, señalado por el provider real): registra
/// el handler de background y arranca la presentación en foreground. Si el
/// provider no es el real (desktop/web, o Android con Firebase caído) no toca
/// Firebase ni el plugin de notificaciones.
Future<void> startPushDisplay(PushTokenProvider provider) async {
  if (provider is! FirebaseMessagingPushTokenProvider) return;
  FirebaseMessaging.onBackgroundMessage(pushFirebaseBackgroundHandler);
  final notifier = FlutterLocalNotifier(FlutterLocalNotificationsPlugin());
  await notifier.init();
  ForegroundPushPresenter(
    messages: FirebaseMessaging.onMessage,
    notifier: notifier,
  ).start();
}
