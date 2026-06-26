import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ai.tool → aiTool con toolName y runId', () {
    final e = MonitorEvent.fromFrame('ai.tool', <String, dynamic>{
      'runId': 'r1',
      'chatLid': 'c1',
      'toolName': 'inspect_flow',
      'toolError': false,
      'at': '2026-06-10T10:00:00Z',
    });
    expect(e.kind, MonitorEventKind.aiTool);
    expect(e.toolName, 'inspect_flow');
    expect(e.runId, 'r1');
  });

  test('ai.completed → tokens in/out y model', () {
    final e = MonitorEvent.fromFrame('ai.completed', <String, dynamic>{
      'runId': 'r1',
      'model': 'glm-4.6',
      'tokensIn': 120,
      'tokensOut': 45,
      'at': '2026-06-10T10:00:01Z',
    });
    expect(e.kind, MonitorEventKind.aiCompleted);
    expect(e.model, 'glm-4.6');
    expect(e.tokensIn, 120);
    expect(e.tokensOut, 45);
  });

  test('flow.step → flowStep con flowId y stepIdx', () {
    final e = MonitorEvent.fromFrame('flow.step', <String, dynamic>{
      'flowId': 'f1',
      'chatLid': 'c1',
      'stepIdx': 3,
      'at': '2026-06-10T10:00:02Z',
    });
    expect(e.kind, MonitorEventKind.flowStep);
    expect(e.flowId, 'f1');
    expect(e.stepIdx, 3);
  });

  test('agent.alert → alert con category, title y detail', () {
    final e = MonitorEvent.fromFrame('agent.alert', <String, dynamic>{
      'chatLid': 'c1',
      'category': 'human_needed',
      'title': 'Cliente molesto',
      'detail': 'pide hablar con una persona',
      'at': '2026-06-10T10:00:03Z',
    });
    expect(e.kind, MonitorEventKind.alert);
    expect(e.category, 'human_needed');
    expect(e.title, 'Cliente molesto');
    expect(e.detail, 'pide hablar con una persona');
  });

  test('topic desconocido → unknown sin crashear', () {
    final e = MonitorEvent.fromFrame('algo.raro', <String, dynamic>{});
    expect(e.kind, MonitorEventKind.unknown);
  });

  test('campos ausentes → defaults seguros', () {
    final e = MonitorEvent.fromFrame('ai.failed', <String, dynamic>{});
    expect(e.kind, MonitorEventKind.aiFailed);
    expect(e.toolName, '');
    expect(e.tokensIn, 0);
    expect(e.toolError, isFalse);
  });
}
