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

    test('hidrata una corrida fresca y deduplica el borde por timestamp', () async {
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
        at(MonitorEventKind.aiTool, t0.add(const Duration(seconds: 5)), tool: 'nuevo'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.events, hasLength(3));
      expect(cubit.state.events.last.toolName, 'nuevo');
      await cubit.close();
    });

    test('corrida vieja no se hidrata (gate de frescura)', () async {
      final catchup = _FakeCatchup(
        run: (runId: 'R1', at: DateTime.utc(2020)),
        snapshot: <MonitorEvent>[at(MonitorEventKind.aiTurn, DateTime.utc(2020))],
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

    test('guarda de turno colgado sintetiza el cierre de una corrida hidratada', () {
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
        async.elapse(const Duration(seconds: 6));
        expect(cubit.state.events.last.kind, MonitorEventKind.aiCompleted);
        cubit.close();
      });
    });

    test('un evento live re-arma la guarda (no cierra una corrida viva)', () {
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
          at(MonitorEventKind.aiTool, t0.add(const Duration(seconds: 10)), tool: 'x'),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 3)); // 6s total; re-armado a los 3s
        expect(cubit.state.events.last.kind, MonitorEventKind.aiTool);
        cubit.close();
      });
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
  Future<({String runId, DateTime at})?> activeRun(String botId, String chatLid) async =>
      run;

  @override
  Future<List<MonitorEvent>> catchup(
    String botId,
    String chatLid,
    String runId,
  ) async => snapshot;
}
