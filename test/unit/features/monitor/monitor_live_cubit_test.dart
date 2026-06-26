import 'dart:async';

import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
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
}
