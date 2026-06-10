import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/repositories/firebase_messaging_push_token_provider.dart';
import '../data/repositories/flutter_local_notifier.dart';
import '../domain/repositories/push_token_provider.dart';
import 'foreground_push_presenter.dart';
import 'push_tap_coordinator.dart';

/// Handler de mensajes en background. El SO ya pinta en la bandeja los mensajes
/// de notificación cuando la app no está en foreground; para el MVP no hace
/// falta trabajo extra aquí (el procesamiento de data-messages en background es
/// trabajo futuro). Debe ser top-level y anotado para el entry-point de la VM.
@pragma('vm:entry-point')
Future<void> pushFirebaseBackgroundHandler(RemoteMessage message) async {}

/// Cablea la visualización Y la navegación de push cuando el transporte real
/// está activo (Android con Firebase inicializado, señalado por el provider
/// real): registra el handler de background, presenta los push en foreground
/// y navega al destino al TOCAR una notificación — de la bandeja del sistema
/// (app en background o muerta) o local (mostrada en foreground). Si el
/// provider no es el real (desktop/web, o Android con Firebase caído) no toca
/// Firebase ni el plugin de notificaciones.
Future<void> startPushDisplay(
  PushTokenProvider provider, {
  required AuthBloc authBloc,
  required void Function(String location) navigate,
}) async {
  if (provider is! FirebaseMessagingPushTokenProvider) return;
  FirebaseMessaging.onBackgroundMessage(pushFirebaseBackgroundHandler);

  // Un solo canal de taps: los de Firebase (bandeja del sistema) y los de las
  // notificaciones locales (foreground) convergen al mismo coordinator. Vive
  // tanto como la app (este bootstrap no tiene teardown), igual que los
  // streams del plugin que lo alimentan.
  // ignore: close_sinks
  final taps = StreamController<Map<String, Object?>>.broadcast();

  final notifier = FlutterLocalNotifier(FlutterLocalNotificationsPlugin());
  await notifier.init(
    onTap: (payload) {
      final data = _decodePayload(payload);
      if (data != null) taps.add(data);
    },
  );
  ForegroundPushPresenter(
    messages: FirebaseMessaging.onMessage,
    notifier: notifier,
  ).start();

  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => taps.add(Map<String, Object?>.from(message.data)),
  );

  final coordinator = PushTapCoordinator(
    authBloc: authBloc,
    taps: taps.stream,
    // Cold start: primero el push de FCM que lanzó la app; si no, la
    // notificación local que la lanzó (push recibido en foreground, tocado
    // con la app ya muerta).
    initialTap: () async {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null && initial.data.isNotEmpty) {
        return Map<String, Object?>.from(initial.data);
      }
      return _decodePayload(await notifier.launchPayload());
    },
    navigate: navigate,
  );
  unawaited(coordinator.start());
}

Map<String, Object?>? _decodePayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic>
        ? Map<String, Object?>.from(decoded)
        : null;
  } on FormatException {
    return null;
  }
}
