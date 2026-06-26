import 'dart:async';

import 'package:ataulfo/features/monitor/data/datasources/monitor_activity_datasource.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_attention_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBotDs implements MonitorBotActivityDatasource {
  _FakeBotDs(this.ctrl);
  final StreamController<MonitorEvent> ctrl;
  @override
  Stream<MonitorEvent> botActivity(String botId) => ctrl.stream;
}

MonitorEvent _ev(MonitorEventKind kind, String chatLid) => MonitorEvent(
  kind: kind,
  topic: '',
  at: DateTime.utc(2026, 6, 20),
  chatLid: chatLid,
);

void main() {
  test('marca chats con fallo o alerta; ignora actividad normal', () async {
    final ctrl = StreamController<MonitorEvent>();
    final cubit = MonitorAttentionCubit(_FakeBotDs(ctrl))..watch('b1');
    ctrl.add(_ev(MonitorEventKind.aiTool, 'chatA')); // normal: no marca
    ctrl.add(_ev(MonitorEventKind.aiFailed, 'chatB'));
    ctrl.add(_ev(MonitorEventKind.alert, 'chatC'));
    ctrl.add(_ev(MonitorEventKind.flowFailed, 'chatD'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.needsAttention, <String>{'chatB', 'chatC', 'chatD'});
    await cubit.close();
    await ctrl.close();
  });

  test('clear quita un chat del set (al abrirlo)', () async {
    final ctrl = StreamController<MonitorEvent>();
    final cubit = MonitorAttentionCubit(_FakeBotDs(ctrl))..watch('b1');
    ctrl.add(_ev(MonitorEventKind.aiFailed, 'chatB'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.needsAttention, contains('chatB'));

    cubit.clear('chatB');
    expect(cubit.state.needsAttention, isNot(contains('chatB')));
    await cubit.close();
    await ctrl.close();
  });
}
