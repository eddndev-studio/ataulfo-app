import 'package:ataulfo/features/notifications/application/push_route_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mensaje entrante → chats del bot', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'message.inbound.new',
        'botId': 'b1',
      }),
      '/bots/b1/sessions',
    );
  });

  test('bot desconectado → pantalla de conexión del bot', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'bot.disconnected',
        'botId': 'b1',
      }),
      '/bots/b1/connect',
    );
  });

  test('flujo fallido → detalle del bot', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'flow.failed',
        'botId': 'b1',
      }),
      '/bots/b1',
    );
  });

  test('evento desconocido o sin botId → bandeja de notificaciones', () {
    expect(
      pushRouteFor(<String, Object?>{'eventType': 'algo.nuevo'}),
      '/notifications',
    );
    expect(
      pushRouteFor(<String, Object?>{'eventType': 'message.inbound.new'}),
      '/notifications',
    );
    expect(pushRouteFor(const <String, Object?>{}), '/notifications');
  });

  test('botId se codifica para la URL', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'flow.failed',
        'botId': 'a/b',
      }),
      '/bots/a%2Fb',
    );
  });
}
