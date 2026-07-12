import 'dart:async';

import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/data/datasources/monitor_catchup_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Datasource de prueba: un StreamController que el test alimenta para simular
/// el SSE del monitor.
class _FakeDs implements MonitorActivityDatasource {
  // Lo cierra el tearDown del grupo; el lint no puede rastrearlo hasta ahí.
  // ignore: close_sinks
  final StreamController<MonitorEvent> ctrl =
      StreamController<MonitorEvent>.broadcast();
  String? lastBotId;
  String? lastChatLid;

  @override
  Stream<MonitorEvent> activity(String botId, String chatLid) {
    lastBotId = botId;
    lastChatLid = chatLid;
    return ctrl.stream;
  }
}

MonitorEvent _ev(MonitorEventKind kind, {String tool = ''}) => MonitorEvent(
  kind: kind,
  topic: 'ai.tool',
  at: DateTime.utc(2026, 6, 10, 10),
  toolName: tool,
);

void main() {
  late _FakeDs ds;

  setUp(() => ds = _FakeDs());
  tearDown(() async => ds.ctrl.close());

  blocTest<MonitorLiveCubit, MonitorLiveState>(
    'watch se suscribe al (bot, chat) y acumula los eventos en orden',
    build: () => MonitorLiveCubit(ds),
    act: (c) async {
      c.watch('b1', 'chat1');
      ds.ctrl.add(_ev(MonitorEventKind.aiTurn));
      await Future<void>.delayed(Duration.zero);
      ds.ctrl.add(_ev(MonitorEventKind.aiTool, tool: 'inspect_flow'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <dynamic>[
      isA<MonitorLiveState>().having((s) => s.events.length, 'len', 1),
      isA<MonitorLiveState>()
          .having((s) => s.events.length, 'len', 2)
          .having((s) => s.events.last.toolName, 'último', 'inspect_flow'),
    ],
    verify: (_) {
      expect(ds.lastBotId, 'b1');
      expect(ds.lastChatLid, 'chat1');
    },
  );

  blocTest<MonitorLiveCubit, MonitorLiveState>(
    'acota el historial a los más recientes (no crece sin límite)',
    build: () => MonitorLiveCubit(ds, maxEvents: 3),
    act: (c) async {
      c.watch('b1', 'chat1');
      for (var i = 0; i < 5; i++) {
        ds.ctrl.add(_ev(MonitorEventKind.aiTool, tool: 't$i'));
        await Future<void>.delayed(Duration.zero);
      }
    },
    skip: 4, // solo asevera el estado final
    expect: () => <dynamic>[
      isA<MonitorLiveState>()
          .having((s) => s.events.length, 'len acotada', 3)
          .having((s) => s.events.first.toolName, 'descartó los viejos', 't2')
          .having((s) => s.events.last.toolName, 'conserva el último', 't4'),
    ],
  );

  blocTest<MonitorLiveCubit, MonitorLiveState>(
    'un sentinel reconnect marca reconnecting; un evento real lo limpia',
    build: () => MonitorLiveCubit(ds),
    act: (c) async {
      c.watch('b1', 'chat1');
      ds.ctrl.add(_ev(MonitorEventKind.reconnect));
      await Future<void>.delayed(Duration.zero);
      ds.ctrl.add(_ev(MonitorEventKind.aiTurn));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <dynamic>[
      isA<MonitorLiveState>()
          .having((s) => s.reconnecting, 'reconectando', true)
          .having((s) => s.events.length, 'el sentinel no es un evento', 0),
      isA<MonitorLiveState>()
          .having((s) => s.reconnecting, 'de vuelta en vivo', false)
          .having((s) => s.events.length, 'el evento real sí cuenta', 1),
    ],
  );

  blocTest<MonitorLiveCubit, MonitorLiveState>(
    'un sentinel connected limpia reconnecting SIN actividad del bot',
    build: () => MonitorLiveCubit(ds),
    act: (c) async {
      c.watch('b1', 'chat1');
      ds.ctrl.add(_ev(MonitorEventKind.reconnect));
      await Future<void>.delayed(Duration.zero);
      ds.ctrl.add(_ev(MonitorEventKind.connected));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <dynamic>[
      isA<MonitorLiveState>().having((s) => s.reconnecting, 'cayó', true),
      isA<MonitorLiveState>()
          .having((s) => s.reconnecting, 'feed vivo de nuevo', false)
          .having((s) => s.events.length, 'connected no es un evento', 0),
    ],
  );

  blocTest<MonitorLiveCubit, MonitorLiveState>(
    'connected estando ya en vivo es no-op (no re-emite)',
    build: () => MonitorLiveCubit(ds),
    act: (c) async {
      c.watch('b1', 'chat1');
      ds.ctrl.add(_ev(MonitorEventKind.connected));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <dynamic>[],
  );

  group('actividad del run VIGENTE (La Traza F5)', () {
    MonitorEvent ev(
      MonitorEventKind kind, {
      String runId = '',
      String tool = '',
      String error = '',
      DateTime? at,
    }) => MonitorEvent(
      kind: kind,
      topic: '',
      at: at ?? DateTime.utc(2026, 7, 1, 10),
      runId: runId,
      toolName: tool,
      error: error,
    );

    Future<void> feed(MonitorEvent e) async {
      ds.ctrl.add(e);
      await Future<void>.delayed(Duration.zero);
    }

    test('un terminal aiCompleted cierra la corrida: lista vacía', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      await feed(ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'x'));
      expect(c.state.events, hasLength(2));
      await feed(ev(MonitorEventKind.aiCompleted, runId: 'r1'));
      expect(c.state.events, isEmpty);
      expect(c.state.failure, isNull);
      await c.close();
    });

    test(
      'aiFailed cierra la corrida y RETIENE runId/error del fallo',
      () async {
        final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
        await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
        await feed(
          ev(
            MonitorEventKind.aiFailed,
            runId: 'r1',
            error: 'deadline exceeded',
          ),
        );
        expect(c.state.events, isEmpty);
        final f = c.state.failure!;
        expect(f.isFlow, isFalse);
        expect(f.runId, 'r1');
        expect(f.error, 'deadline exceeded');
        await c.close();
      },
    );

    test('una corrida nueva (runId distinto) arranca lista fresca y limpia '
        'el fallo anterior', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      await feed(ev(MonitorEventKind.aiFailed, runId: 'r1', error: 'boom'));
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r2'));
      expect(c.state.events, hasLength(1));
      expect(c.state.events.single.runId, 'r2');
      expect(c.state.failure, isNull);
      await c.close();
    });

    test('el frame rezagado de una corrida YA cerrada no se anexa', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      await feed(ev(MonitorEventKind.aiCompleted, runId: 'r1'));
      await feed(ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'tarde'));
      expect(c.state.events, isEmpty);
      await c.close();
    });

    test('los eventos flow.* se anexan a la corrida vigente', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      await feed(ev(MonitorEventKind.flowStarted, runId: ''));
      expect(c.state.events, hasLength(2));
      // El terminal del flujo DENTRO de la corrida no la cierra (es un paso).
      await feed(ev(MonitorEventKind.flowCompleted, runId: ''));
      expect(c.state.events, hasLength(2));
      await c.close();
    });

    test('carril solo-flujo: flowCompleted limpia; flowFailed retiene fallo '
        'de flujo (sin runId)', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.flowStarted));
      await feed(ev(MonitorEventKind.flowCompleted));
      expect(c.state.events, isEmpty);
      await feed(ev(MonitorEventKind.flowStarted));
      await feed(ev(MonitorEventKind.flowFailed, error: 'paso inválido'));
      expect(c.state.events, isEmpty);
      final f = c.state.failure!;
      expect(f.isFlow, isTrue);
      expect(f.runId, '');
      await c.close();
    });

    test('agent.alert no toca la traza viva, pero se RETIENE para el banner '
        'y sobrevive al terminal de la corrida', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      await feed(ev(MonitorEventKind.alert));
      expect(c.state.events, hasLength(1));
      expect(c.state.events.single.kind, MonitorEventKind.aiTurn);
      expect(c.state.alert?.kind, MonitorEventKind.alert);
      // El cierre de la corrida vacía la traza SIN descartar la alerta (el
      // operador la descarta con la X del banner, no un evento cualquiera).
      await feed(ev(MonitorEventKind.aiCompleted, runId: 'r1'));
      expect(c.state.events, isEmpty);
      expect(c.state.alert, isNotNull);
      await c.close();
    });

    test(
      're-watch (cambio de chat) limpia la actividad del chat anterior',
      () async {
        final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
        await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
        expect(c.state.events, hasLength(1));
        c.watch('b1', 'c2');
        expect(c.state.events, isEmpty);
        await c.close();
      },
    );
  });

  test('close cancela la suscripción (no fuga)', () async {
    final c = MonitorLiveCubit(ds)..watch('b1', 'chat1');
    await c.close();
    // Emitir tras cerrar no debe lanzar (la suscripción ya se canceló).
    ds.ctrl.add(_ev(MonitorEventKind.aiTurn));
    await Future<void>.delayed(Duration.zero);
    expect(ds.ctrl.hasListener, isFalse);
  });

  group('catch-up del run en curso (S39)', () {
    MonitorEvent at(MonitorEventKind kind, DateTime when, {String tool = ''}) =>
        MonitorEvent(
          kind: kind,
          topic: kind == MonitorEventKind.aiTool ? 'ai.tool' : 'ai.turn',
          at: when,
          runId: 'R1',
          toolName: tool,
        );

    test(
      'hidrata una corrida fresca y deduplica el borde por timestamp',
      () async {
        final t0 = DateTime.now().toUtc();
        final catchup = _FakeCatchup(
          run: (runId: 'R1', at: t0.add(const Duration(seconds: 1))),
          snapshot: <MonitorEvent>[
            at(MonitorEventKind.aiTurn, t0),
            at(
              MonitorEventKind.aiTool,
              t0.add(const Duration(seconds: 1)),
              tool: 'send_message',
            ),
          ],
        );
        final cubit = MonitorLiveCubit(ds, catchup: catchup);
        cubit.watch('b1', 'c1');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(cubit.state.events, hasLength(2));

        // Duplicado (mismo run, dentro del corte) se descarta.
        ds.ctrl.add(at(MonitorEventKind.aiTool, t0, tool: 'dup'));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.events, hasLength(2));

        // Evento live posterior al corte se conserva.
        ds.ctrl.add(
          at(
            MonitorEventKind.aiTool,
            t0.add(const Duration(seconds: 5)),
            tool: 'nuevo',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.events, hasLength(3));
        expect(cubit.state.events.last.toolName, 'nuevo');
        await cubit.close();
      },
    );

    test('corrida vieja no se hidrata (gate de frescura)', () async {
      final catchup = _FakeCatchup(
        run: (runId: 'R1', at: DateTime.utc(2020)),
        snapshot: <MonitorEvent>[
          at(MonitorEventKind.aiTurn, DateTime.utc(2020)),
        ],
      );
      final cubit = MonitorLiveCubit(ds, catchup: catchup);
      cubit.watch('b1', 'c1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state.events, isEmpty);
      await cubit.close();
    });

    test('sin corrida activa no hidrata', () async {
      final catchup = _FakeCatchup(run: null);
      final cubit = MonitorLiveCubit(ds, catchup: catchup);
      cubit.watch('b1', 'c1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state.events, isEmpty);
      await cubit.close();
    });

    test('guarda de turno colgado marca stalled SIN inventar un terminal', () {
      fakeAsync((async) {
        final t0 = DateTime.now().toUtc();
        final catchup = _FakeCatchup(
          run: (runId: 'R1', at: t0),
          snapshot: <MonitorEvent>[at(MonitorEventKind.aiTurn, t0)],
        );
        final cubit = MonitorLiveCubit(
          ds,
          catchup: catchup,
          stuckTurnTimeout: const Duration(seconds: 5),
        );
        cubit.watch('b1', 'c1');
        async.flushMicrotasks();
        expect(cubit.state.events.last.kind, MonitorEventKind.aiTurn);
        expect(cubit.state.stalled, isFalse);
        async.elapse(const Duration(seconds: 6));
        // Se marca colgado, pero la línea de tiempo sigue veraz (sin aiCompleted
        // falso): un turno solo lento no debe ganar un terminal inventado.
        expect(cubit.state.stalled, isTrue);
        expect(cubit.state.events.last.kind, MonitorEventKind.aiTurn);
        cubit.close();
      });
    });

    test(
      'un evento live re-arma la guarda (no marca colgada una corrida viva)',
      () {
        fakeAsync((async) {
          final t0 = DateTime.now().toUtc();
          final catchup = _FakeCatchup(
            run: (runId: 'R1', at: t0),
            snapshot: <MonitorEvent>[at(MonitorEventKind.aiTurn, t0)],
          );
          final cubit = MonitorLiveCubit(
            ds,
            catchup: catchup,
            stuckTurnTimeout: const Duration(seconds: 5),
          );
          cubit.watch('b1', 'c1');
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 3));
          ds.ctrl.add(
            at(
              MonitorEventKind.aiTool,
              t0.add(const Duration(seconds: 10)),
              tool: 'x',
            ),
          );
          async.flushMicrotasks();
          async.elapse(
            const Duration(seconds: 3),
          ); // 6s total; re-armado a los 3s
          expect(cubit.state.events.last.kind, MonitorEventKind.aiTool);
          expect(cubit.state.stalled, isFalse);
          cubit.close();
        });
      },
    );

    test('un evento real tras stalled limpia el flag', () {
      fakeAsync((async) {
        final t0 = DateTime.now().toUtc();
        final catchup = _FakeCatchup(
          run: (runId: 'R1', at: t0),
          snapshot: <MonitorEvent>[at(MonitorEventKind.aiTurn, t0)],
        );
        final cubit = MonitorLiveCubit(
          ds,
          catchup: catchup,
          stuckTurnTimeout: const Duration(seconds: 5),
        );
        cubit.watch('b1', 'c1');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 6));
        expect(cubit.state.stalled, isTrue);
        // Llega actividad real: el turno seguía vivo, se rehabilita "Pensando…".
        ds.ctrl.add(
          at(
            MonitorEventKind.aiTool,
            t0.add(const Duration(seconds: 20)),
            tool: 'x',
          ),
        );
        async.flushMicrotasks();
        expect(cubit.state.stalled, isFalse);
        expect(cubit.state.events.last.kind, MonitorEventKind.aiTool);
        cubit.close();
      });
    });

    test(
      'hidratar un run ya terminado no arma la guarda (no lo marca colgado)',
      () {
        fakeAsync((async) {
          final t0 = DateTime.now().toUtc();
          // El terminal real llegó (p.ej. live durante la hidratación) y quedó como
          // último evento del merge: no hay nada que vigilar.
          final catchup = _FakeCatchup(
            run: (runId: 'R1', at: t0),
            snapshot: <MonitorEvent>[
              at(MonitorEventKind.aiTurn, t0),
              at(
                MonitorEventKind.aiCompleted,
                t0.add(const Duration(seconds: 1)),
              ),
            ],
          );
          final cubit = MonitorLiveCubit(
            ds,
            catchup: catchup,
            stuckTurnTimeout: const Duration(seconds: 5),
          );
          cubit.watch('b1', 'c1');
          async.flushMicrotasks();
          expect(cubit.state.events.last.kind, MonitorEventKind.aiCompleted);
          async.elapse(const Duration(seconds: 6));
          expect(cubit.state.stalled, isFalse);
          cubit.close();
        });
      },
    );
  });

  group('cierres de revisión F5', () {
    MonitorEvent ev(
      MonitorEventKind kind, {
      String runId = '',
      String tool = '',
      String error = '',
      DateTime? at,
    }) => MonitorEvent(
      kind: kind,
      topic: '',
      at: at ?? DateTime.utc(2026, 7, 1, 10),
      runId: runId,
      toolName: tool,
      error: error,
    );

    Future<void> feed(MonitorEvent e) async {
      ds.ctrl.add(e);
      await Future<void>.delayed(Duration.zero);
    }

    test('un terminal REZAGADO de otra corrida no apaga la vigente', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r2'));
      // El ai.failed de r1 llega con jitter DESPUÉS de arrancar r2.
      await feed(ev(MonitorEventKind.aiFailed, runId: 'r1', error: 'boom'));
      expect(c.state.runId, 'r2');
      expect(c.state.events, hasLength(1));
      expect(c.state.failure, isNull);
      // Un terminal degradado SIN runId sí cierra la vigente.
      await feed(ev(MonitorEventKind.aiCompleted));
      expect(c.state.events, isEmpty);
      await c.close();
    });

    test('el tope de eventos deja `truncated` pegajoso', () async {
      final c = MonitorLiveCubit(ds)..watch('b1', 'c1');
      await feed(ev(MonitorEventKind.aiTurn, runId: 'r1'));
      for (var i = 0; i < 110; i++) {
        ds.ctrl.add(ev(MonitorEventKind.aiTool, runId: 'r1', tool: 't$i'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(c.state.events.length, lessThanOrEqualTo(100));
      expect(c.state.truncated, isTrue);
      await c.close();
    });

    test('el snapshot de la hidratación NO pisa una corrida nueva arrancada '
        'en vivo durante el fetch', () async {
      final t0 = DateTime.now().toUtc();
      final catchup = _GatedCatchup(
        run: (runId: 'R1', at: t0),
        snapshot: <MonitorEvent>[
          ev(MonitorEventKind.aiTurn, runId: 'R1', at: t0),
        ],
      );
      final c = MonitorLiveCubit(ds, catchup: catchup)..watch('b1', 'c1');
      await Future<void>.delayed(Duration.zero);
      // R2 arranca EN VIVO con el fetch del snapshot de R1 aún en vuelo.
      await feed(
        ev(
          MonitorEventKind.aiTurn,
          runId: 'R2',
          at: t0.add(const Duration(seconds: 2)),
        ),
      );
      expect(c.state.runId, 'R2');
      catchup.gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.state.runId, 'R2');
      expect(c.state.events, hasLength(1));
      await c.close();
    });
  });
}

/// Catch-up de prueba: devuelve un run/snapshot fijos (o null) para ejercer la
/// hidratación del cubit sin red.
class _FakeCatchup implements MonitorCatchupDatasource {
  _FakeCatchup({this.run, this.snapshot = const <MonitorEvent>[]});

  final ({String runId, DateTime at})? run;
  final List<MonitorEvent> snapshot;

  @override
  Future<({String runId, DateTime at})?> activeRun(
    String botId,
    String chatLid,
  ) async => run;

  @override
  Future<List<MonitorEvent>> catchup(
    String botId,
    String chatLid,
    String runId,
  ) async => snapshot;
}

/// Catch-up cuyo snapshot espera una compuerta: reproduce el fetch en vuelo
/// mientras la actividad en vivo avanza.
class _GatedCatchup implements MonitorCatchupDatasource {
  _GatedCatchup({required this.run, required this.snapshot});

  final ({String runId, DateTime at})? run;
  final List<MonitorEvent> snapshot;
  final Completer<void> gate = Completer<void>();

  @override
  Future<({String runId, DateTime at})?> activeRun(
    String botId,
    String chatLid,
  ) async => run;

  @override
  Future<List<MonitorEvent>> catchup(
    String botId,
    String chatLid,
    String runId,
  ) async {
    await gate.future;
    return snapshot;
  }
}
