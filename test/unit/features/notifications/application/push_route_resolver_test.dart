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

  test('mensaje entrante CON chatLID → deep-link al hilo', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'message.inbound.new',
        'botId': 'b1',
        'chatLID': '5215550000001',
      }),
      '/bots/b1/sessions/5215550000001',
    );
  });

  test(
    'agent.alert CON chatLID → deep-link al hilo (el bot pidió ayuda ahí)',
    () {
      expect(
        pushRouteFor(<String, Object?>{
          'eventType': 'agent.alert',
          'botId': 'b1',
          'chatLID': '5215@g.us',
        }),
        '/bots/b1/sessions/5215%40g.us',
      );
    },
  );

  test('agent.alert SIN chatLID → bandeja (no hay a qué chat ir)', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'agent.alert',
        'botId': 'b1',
      }),
      '/notifications',
    );
  });

  test('flujo fallido CON chatLID → ejecuciones del chat', () {
    expect(
      pushRouteFor(<String, Object?>{
        'eventType': 'flow.failed',
        'botId': 'b1',
        'chatLID': '5215550000002',
      }),
      '/bots/b1/sessions/5215550000002/executions',
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
