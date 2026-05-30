import 'dart:async';

/// Backoff exponencial acotado para reconexiones: 0.5s, 1s, 2s, 4s… con techo
/// de 30s. `attempt` es 1-based (el primer reintento es 1). Sin jitter: el
/// número de clientes por bot es bajo, no hay tormenta de reconexión que
/// dispersar.
Future<void> expoBackoff(int attempt) {
  final shift = (attempt - 1).clamp(0, 6); // 1<<6 = 64 → 32s, ya sobre el techo
  final ms = (500 * (1 << shift)).clamp(500, 30000);
  return Future<void>.delayed(Duration(milliseconds: ms));
}

/// Envuelve una fábrica de conexiones efímeras en un stream perdurable que se
/// reconecta solo. [connect] abre UNA conexión (un stream que vive hasta que el
/// productor lo cierra o falla); este combinador la reabre tras cada cierre o
/// error, esperando [backoff] entre intentos, hasta que el consumidor cancela
/// la suscripción.
///
/// El contador de intentos se reinicia en cuanto una conexión entrega al menos
/// un evento: una conexión sana que cae tras horas reconecta rápido; una que
/// falla de inmediato, repetidas veces, espacia los reintentos.
///
/// Cancelación: al cancelar la suscripción NO se vuelve a conectar —ni estando
/// conectado ni durante el backoff— para no dejar un loop de reconexión vivo
/// (drena batería). La conexión interna se cierra de inmediato y el loop se
/// desmonta sin quedar suspendido.
///
/// HUECO CONOCIDO: la reconexión reanuda la entrega EN VIVO; no rellena los
/// eventos emitidos durante el corte (el productor no reproduce historia). Para
/// cerrarlo, [reconnectMarker]: si se da, su valor se emite al stream cada vez
/// que se REESTABLECE una conexión (no en la primera), como señal para que el
/// consumidor reconcilie contra la verdad autoritativa (p. ej. un fetch HTTP).
Stream<T> reconnectingStream<T>(
  Stream<T> Function() connect, {
  Future<void> Function(int attempt) backoff = expoBackoff,
  T Function()? reconnectMarker,
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? inner;
  Completer<void>? connectionClosed;
  var cancelled = false;
  var firstConnect = true;
  var attempt = 0;

  // Libera el await de la conexión en curso —al cerrarse, fallar, o al cancelar
  // el consumidor— sin completar dos veces. Cancelar la suscripción interna NO
  // dispara onDone, así que la cancelación debe soltar este wait a mano.
  void releaseConnection() {
    if (connectionClosed != null && !connectionClosed!.isCompleted) {
      connectionClosed!.complete();
    }
  }

  Future<void> run() async {
    while (!cancelled) {
      var delivered = false;
      final closed = Completer<void>();
      connectionClosed = closed;
      inner = connect().listen(
        (event) {
          delivered = true;
          controller.add(event);
        },
        onError: (Object _) => releaseConnection(),
        onDone: releaseConnection,
        cancelOnError: true,
      );
      if (cancelled) break;
      if (!firstConnect && reconnectMarker != null) {
        controller.add(reconnectMarker());
      }
      firstConnect = false;
      await closed.future;
      await inner?.cancel();
      inner = null;
      if (cancelled) break;
      attempt = delivered ? 1 : attempt + 1;
      await backoff(attempt);
    }
    if (!controller.isClosed) await controller.close();
  }

  controller = StreamController<T>(
    onListen: () => unawaited(run()),
    onCancel: () async {
      cancelled = true;
      releaseConnection(); // desbloquea el await de la conexión en curso
      final s = inner;
      inner = null;
      await s?.cancel();
    },
  );
  return controller.stream;
}
