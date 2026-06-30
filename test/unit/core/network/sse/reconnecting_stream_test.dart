import 'dart:async';

import 'package:ataulfo/core/network/sse/reconnecting_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Backoff instantáneo que registra los intentos con los que se le llama.
  /// Permite probar la progresión sin esperas reales.
  ({Future<void> Function(int) fn, List<int> attempts}) recordingBackoff() {
    final attempts = <int>[];
    return (
      fn: (int attempt) async {
        attempts.add(attempt);
      },
      attempts: attempts,
    );
  }

  test('reenvía los eventos de una conexión sana', () async {
    final inner = StreamController<int>();
    var calls = 0;
    final bk = recordingBackoff();

    final stream = reconnectingStream<int>(() {
      calls++;
      return inner.stream;
    }, backoff: bk.fn);

    final got = <int>[];
    final sub = stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);

    inner.add(1);
    inner.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(got, <int>[1, 2]);
    expect(calls, 1);
    await sub.cancel();
    await inner.close();
  });

  test('reconecta tras un error de la conexión y reanuda la entrega', () async {
    var calls = 0;
    final controllers = <StreamController<int>>[];
    final bk = recordingBackoff();

    final stream = reconnectingStream<int>(() {
      final c = StreamController<int>();
      controllers.add(c);
      calls++;
      return c.stream;
    }, backoff: bk.fn);

    final got = <int>[];
    final sub = stream.listen(got.add);
    await Future<void>.delayed(Duration.zero);

    controllers[0].add(1);
    await Future<void>.delayed(Duration.zero);
    // La primera conexión falla: el combinador debe reconectar (segundo connect).
    controllers[0].addError(Exception('caída de transporte'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2, reason: 'tras el error debe reconectar');
    controllers[1].add(2);
    await Future<void>.delayed(Duration.zero);

    expect(got, <int>[1, 2]);
    await sub.cancel();
  });

  test('reconecta también cuando la conexión se cierra normalmente', () async {
    var calls = 0;
    final controllers = <StreamController<int>>[];
    final bk = recordingBackoff();

    final stream = reconnectingStream<int>(() {
      final c = StreamController<int>();
      controllers.add(c);
      calls++;
      return c.stream;
    }, backoff: bk.fn);

    final sub = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    // El productor cierra el stream sin error (servidor cerró la conexión).
    await controllers[0].close();
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2, reason: 'un cierre normal también debe reconectar');
    await sub.cancel();
  });

  test(
    'el backoff escala en fallos seguidos y se reinicia tras entregar',
    () async {
      final controllers = <StreamController<int>>[];
      final bk = recordingBackoff();

      final stream = reconnectingStream<int>(() {
        final c = StreamController<int>();
        controllers.add(c);
        return c.stream;
      }, backoff: bk.fn);

      final sub = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      // Dos conexiones que fallan SIN entregar nada: el intento escala 1, 2.
      await controllers[0].close();
      await Future<void>.delayed(Duration.zero);
      await controllers[1].close();
      await Future<void>.delayed(Duration.zero);
      // Tercera conexión entrega un evento y luego cae: el intento se reinicia a 1.
      controllers[2].add(42);
      await Future<void>.delayed(Duration.zero);
      await controllers[2].close();
      await Future<void>.delayed(Duration.zero);

      expect(
        bk.attempts,
        <int>[1, 2, 1],
        reason:
            'escala en fallos seguidos; se reinicia tras una conexión que entregó',
      );
      await sub.cancel();
    },
  );

  test(
    'emite reconnectMarker en cada reconexión, nunca en el primer connect',
    () async {
      final controllers = <StreamController<int>>[];
      final bk = recordingBackoff();

      final stream = reconnectingStream<int>(
        () {
          final c = StreamController<int>();
          controllers.add(c);
          return c.stream;
        },
        backoff: bk.fn,
        reconnectMarker: () => -1, // valor distinguible de los mensajes
      );

      final got = <int>[];
      final sub = stream.listen(got.add);
      await Future<void>.delayed(Duration.zero);

      controllers[0].add(1); // primer connect: SIN marcador antes
      await Future<void>.delayed(Duration.zero);
      await controllers[0].close(); // cae → reconecta
      await Future<void>.delayed(Duration.zero);
      controllers[1].add(2); // segundo connect: marcador ANTES de los eventos
      await Future<void>.delayed(Duration.zero);

      expect(
        got,
        <int>[1, -1, 2],
        reason:
            'el marcador (-1) aparece sólo al reconectar, no en el primer connect',
      );
      await sub.cancel();
    },
  );

  test(
    'emite disconnectMarker al CAER la conexión, antes de reconectar',
    () async {
      final controllers = <StreamController<int>>[];
      final bk = recordingBackoff();

      final stream = reconnectingStream<int>(
        () {
          final c = StreamController<int>();
          controllers.add(c);
          return c.stream;
        },
        backoff: bk.fn,
        disconnectMarker: () => -9, // valor distinguible de los mensajes
      );

      final got = <int>[];
      final sub = stream.listen(got.add);
      await Future<void>.delayed(Duration.zero);

      controllers[0].add(1);
      await Future<void>.delayed(Duration.zero);
      await controllers[0]
          .close(); // cae → emite el disconnect ANTES del backoff
      await Future<void>.delayed(Duration.zero);
      controllers[1].add(2);
      await Future<void>.delayed(Duration.zero);

      expect(
        got,
        <int>[1, -9, 2],
        reason:
            'el disconnect (-9) aparece al caer la conexión, no al reconectar',
      );
      await sub.cancel();
    },
  );

  test(
    'un evento excluido por countsAsDelivery NO reinicia el backoff',
    () async {
      final controllers = <StreamController<int>>[];
      final bk = recordingBackoff();

      final stream = reconnectingStream<int>(
        () {
          final c = StreamController<int>();
          controllers.add(c);
          return c.stream;
        },
        backoff: bk.fn,
        // -1 es un sentinel inyectado (no cuenta como entrega).
        countsAsDelivery: (e) => e != -1,
      );

      final sub = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      // Conexión 1: sólo emite el sentinel -1 y cae → NO debe reiniciar (escala).
      controllers[0].add(-1);
      await Future<void>.delayed(Duration.zero);
      await controllers[0].close();
      await Future<void>.delayed(Duration.zero);
      // Conexión 2: ídem, sólo el sentinel y cae.
      controllers[1].add(-1);
      await Future<void>.delayed(Duration.zero);
      await controllers[1].close();
      await Future<void>.delayed(Duration.zero);

      expect(
        bk.attempts,
        <int>[1, 2],
        reason: 'el sentinel no entrega: el intento escala 1,2 (sin reinicio)',
      );
      await sub.cancel();
    },
  );

  test('al cancelar mientras está conectado NO vuelve a conectar', () async {
    var calls = 0;
    final controllers = <StreamController<int>>[];
    final bk = recordingBackoff();

    final stream = reconnectingStream<int>(() {
      final c = StreamController<int>();
      controllers.add(c);
      calls++;
      return c.stream;
    }, backoff: bk.fn);

    final sub = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    await sub.cancel();
    // Tras cancelar, aunque pase tiempo, no debe haber más connect().
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, 1, reason: 'cancelado estando conectado: cero reconexiones');
  });

  test(
    'al cancelar DURANTE el backoff NO vuelve a conectar (sin loop runaway)',
    () async {
      var calls = 0;
      final controllers = <StreamController<int>>[];
      // Backoff lento: deja una ventana para cancelar mientras espera.
      Future<void> slowBackoff(int _) =>
          Future<void>.delayed(const Duration(milliseconds: 100));

      final stream = reconnectingStream<int>(() {
        final c = StreamController<int>();
        controllers.add(c);
        calls++;
        return c.stream;
      }, backoff: slowBackoff);

      final sub = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      // La conexión cae: el combinador entra al backoff (100ms).
      await controllers[0].close();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Cancelamos DURANTE el backoff.
      await sub.cancel();
      // Esperamos más allá de la ventana de backoff: NO debe reconectar.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        calls,
        1,
        reason: 'cancelado durante el backoff: cero reconexiones (no runaway)',
      );
    },
  );
}
