import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/repositories/local_notifier.dart';

/// Muestra como notificación local los push que llegan con la app en
/// foreground. FCM no las pinta solo en ese estado (a diferencia de background,
/// donde el SO las muestra en la bandeja), así que aquí se escucha `onMessage` y
/// se delega la presentación en un [LocalNotifier].
class ForegroundPushPresenter {
  ForegroundPushPresenter({
    required Stream<RemoteMessage> messages,
    required LocalNotifier notifier,
  }) : _messages = messages,
       _notifier = notifier;

  final Stream<RemoteMessage> _messages;
  final LocalNotifier _notifier;
  StreamSubscription<RemoteMessage>? _sub;

  void start() {
    _sub ??= _messages.listen(_onMessage);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title;
    final body = notification.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    // Fire-and-forget: la presentación no debe bloquear el procesamiento del
    // stream de mensajes entrantes. El data viaja como payload para que el
    // tap sepa a dónde navegar.
    unawaited(
      _notifier.show(
        title: title,
        body: body,
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      ),
    );
  }
}
