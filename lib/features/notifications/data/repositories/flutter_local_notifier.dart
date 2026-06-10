import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/repositories/local_notifier.dart';

/// [LocalNotifier] sobre flutter_local_notifications: inicializa el canal
/// Android y muestra cada push entrante en foreground.
class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'ataulfo_push';
  static const _channelName = 'Notificaciones';
  static const _channelDescription = 'Notificaciones push de Ataúlfo';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  int _nextId = 0;

  /// [onTap] recibe el payload de la notificación tocada (con la app viva).
  Future<void> init({void Function(String payload)? onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (onTap != null && payload != null && payload.isNotEmpty) {
          onTap(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  @override
  Future<void> show({String? title, String? body, String? payload}) {
    return _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: _details,
      payload: payload,
    );
  }

  /// Payload de la notificación local que LANZÓ la app (tap con la app
  /// muerta), o null si el arranque fue normal.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}
