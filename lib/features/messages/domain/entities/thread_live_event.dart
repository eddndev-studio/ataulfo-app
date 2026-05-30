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

/// Avanzó el estado de entrega de un OUTBOUND (receipt en vivo: `message.status`).
/// Sólo trae la identidad del mensaje (`externalId`, único global) y el nuevo
/// `status`; el consumidor localiza el mensaje en el hilo y aplica la monotonía
/// (`MessageStatus.transition`). No trae `chatLid`: el scope es implícito por
/// `externalId`.
class LiveStatus extends ThreadLiveEvent {
  const LiveStatus({required this.externalId, required this.status});

  final String externalId;
  final MessageStatus status;

  @override
  bool operator ==(Object other) =>
      other is LiveStatus &&
      other.externalId == externalId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(externalId, status);
}
