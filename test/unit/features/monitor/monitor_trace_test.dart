import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/domain/monitor_trace.dart';
import 'package:flutter_test/flutter_test.dart';

MonitorEvent _ev(
  MonitorEventKind kind, {
  String runId = '',
  int iteration = 0,
  String tool = '',
  bool toolError = false,
  String flowName = '',
  int stepIdx = 0,
  DateTime? at,
}) => MonitorEvent(
  kind: kind,
  topic: '',
  at: at ?? DateTime.utc(2026, 7, 1, 10),
  runId: runId,
  iteration: iteration,
  toolName: tool,
  toolError: toolError,
  flowName: flowName,
  stepIdx: stepIdx,
);

void main() {
  group('nodeFromMonitorEvent — gramática VIVA del hilo real', () {
    test('ai.turn → nodo thinking «Pensando…» (sin texto)', () {
      final n = nodeFromMonitorEvent(_ev(MonitorEventKind.aiTurn))!;
      expect(n.kind, TraceNodeKind.thinking);
      expect(n.titulo, 'Pensando…');
    });

    test('ai.tool → título humano del tool, jamás el nombre crudo', () {
      final n = nodeFromMonitorEvent(
        _ev(MonitorEventKind.aiTool, tool: 'list_flows'),
      )!;
      expect(n.kind, TraceNodeKind.tool);
      expect(n.titulo, 'Consultó los flujos');
    });

    test('ai.tool sin nombre → «Trabajando…»; toolError tiñe el nodo', () {
      final n = nodeFromMonitorEvent(
        _ev(MonitorEventKind.aiTool, toolError: true),
      )!;
      expect(n.titulo, 'Trabajando…');
      expect(n.isError, isTrue);
    });

    test('flow.step con flowName → «Ejecutando <flujo> · paso N»', () {
      final n = nodeFromMonitorEvent(
        _ev(MonitorEventKind.flowStep, flowName: 'Bienvenida', stepIdx: 3),
      )!;
      expect(n.titulo, 'Ejecutando Bienvenida · paso 3');
    });

    test('flow.step sin flowName degrada a «Ejecutando flujo · paso N»', () {
      final n = nodeFromMonitorEvent(
        _ev(MonitorEventKind.flowStep, stepIdx: 1),
      )!;
      expect(n.titulo, 'Ejecutando flujo · paso 1');
    });

    test('flow.started (stepIdx 0) no anuncia paso', () {
      final n = nodeFromMonitorEvent(
        _ev(MonitorEventKind.flowStarted, flowName: 'Bienvenida'),
      )!;
      expect(n.titulo, 'Ejecutando Bienvenida…');
    });

    test('terminales, alertas y sentinels no aportan nodo', () {
      for (final k in <MonitorEventKind>[
        MonitorEventKind.aiCompleted,
        MonitorEventKind.aiFailed,
        MonitorEventKind.flowCompleted,
        MonitorEventKind.flowFailed,
        MonitorEventKind.alert,
        MonitorEventKind.unknown,
        MonitorEventKind.reconnect,
        MonitorEventKind.connected,
      ]) {
        expect(nodeFromMonitorEvent(_ev(k)), isNull, reason: '$k');
      }
    });
  });

  group('monitorLiveTrace', () {
    test('colapsa thinking adyacente (un tramo, un nodo)', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'list_bots'),
      ]);
      expect(t.nodos, hasLength(2));
      expect(t.nodos.first.kind, TraceNodeKind.thinking);
    });

    test('entrada tarde (primer frame no es el ai.turn inicial) ⇒ parcial', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'list_bots'),
      ]);
      expect(t.parcial, isTrue);
      final t2 = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 2),
      ]);
      expect(t2.parcial, isTrue);
      final completo = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
      ]);
      expect(completo.parcial, isFalse);
    });

    test('un flow.step sin su flow.started delata entrada tarde', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.flowStep, stepIdx: 2),
      ]);
      expect(t.parcial, isTrue);
      final ok = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.flowStarted, flowName: 'Alta'),
        _ev(MonitorEventKind.flowStep, flowName: 'Alta', stepIdx: 1),
      ]);
      expect(ok.parcial, isFalse);
    });
  });

  group('liveTraceSummary — renglón-resumen del footer', () {
    test('vacía anuncia «Pensando…» (aún sin frames)', () {
      expect(
        liveTraceSummary(monitorLiveTrace(const <MonitorEvent>[])),
        'Pensando…',
      );
    });

    test('paso actual + conteo de tools: «Consultó los bots · 1 paso»', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'list_bots'),
      ]);
      expect(liveTraceSummary(t), 'Consultó los bots · 1 paso');
    });

    test('plural y elipsis del paso en curso recortada', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'list_bots'),
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'send_message'),
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 2),
      ]);
      // El paso actual es thinking («Pensando…» sin su elipsis) + 2 tools.
      expect(liveTraceSummary(t), 'Pensando · 2 pasos');
    });

    test('parcial NO inventa el número de pasos', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTool, runId: 'r1', tool: 'list_bots'),
      ]);
      expect(liveTraceSummary(t), 'Consultó los bots');
    });

    test('sin tools el resumen es solo el paso actual', () {
      final t = monitorLiveTrace(<MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, runId: 'r1', iteration: 1),
      ]);
      expect(liveTraceSummary(t), 'Pensando');
    });
  });
}
