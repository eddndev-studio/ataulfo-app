import 'message.dart';

/// Un evento del stream en vivo del hilo (S15). Es, o un mensaje nuevo, o un
/// aviso de que la conexión SSE se reestableció tras un corte. La distinción es
/// de dominio: el consumidor pinta los mensajes y, ante una reconexión,
/// reconcilia contra la verdad HTTP —el stream SSE no reproduce los mensajes
/// emitidos durante el corte, así que reconectar exige refrescar para no perder
/// ese tramo.
sealed class ThreadLiveEvent {
  const ThreadLiveEvent();
}

/// Llegó un mensaje en vivo (entrante del contacto o auto-respuesta del bot).
class LiveMessage extends ThreadLiveEvent {
  const LiveMessage(this.message);

  final Message message;

  @override
  bool operator ==(Object other) =>
      other is LiveMessage && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// La conexión en vivo se reconectó tras un corte. No trae datos: es la señal
/// para que el consumidor reconcilie el hilo contra el `GET .../messages`.
class LiveReconnected extends ThreadLiveEvent {
  const LiveReconnected();

  @override
  bool operator ==(Object other) => other is LiveReconnected;

  @override
  int get hashCode => (LiveReconnected).hashCode;
}
