import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/monitor/presentation/widgets/alert_banner.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCubit extends MockCubit<MonitorLiveState>
    implements MonitorLiveCubit {}

MonitorEvent _alert(String title, String detail, int min) => MonitorEvent(
  kind: MonitorEventKind.alert,
  topic: 'agent.alert',
  at: DateTime.utc(2026, 6, 20, 12, min),
  category: 'bot',
  title: title,
  detail: detail,
);

MonitorEvent _tool() => MonitorEvent(
  kind: MonitorEventKind.aiTool,
  topic: 'ai.tool',
  at: DateTime.utc(2026, 6, 20, 12, 30),
);

Widget _wrap(MonitorLiveCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<MonitorLiveCubit>.value(
      value: cubit,
      child: const AlertBanner(),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  _MockCubit cubit, {
  MonitorEvent? alert,
  List<MonitorEvent> events = const <MonitorEvent>[],
}) async {
  whenListen(
    cubit,
    const Stream<MonitorLiveState>.empty(),
    initialState: MonitorLiveState(events: events, alert: alert),
  );
  await tester.pumpWidget(_wrap(cubit));
  await tester.pump();
}

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  testWidgets('una alerta se muestra con título y detalle', (tester) async {
    await _pump(
      tester,
      cubit,
      alert: _alert(
        'Bot desconectado',
        'El bot Ventas perdió la sesión de WhatsApp',
        0,
      ),
    );
    expect(find.byKey(const Key('monitor.alert_banner')), findsOneWidget);
    expect(find.textContaining('Bot desconectado'), findsOneWidget);
    expect(find.textContaining('perdió la sesión'), findsOneWidget);
  });

  testWidgets('muestra la alerta aunque haya actividad posterior', (
    tester,
  ) async {
    await _pump(
      tester,
      cubit,
      alert: _alert('Alerta', 'algo pasó', 0),
      // Actividad después de la alerta: la alerta sigue visible (retenida).
      events: <MonitorEvent>[_tool()],
    );
    expect(find.byKey(const Key('monitor.alert_banner')), findsOneWidget);
  });

  testWidgets('descartar la oculta', (tester) async {
    await _pump(tester, cubit, alert: _alert('Alerta', 'algo pasó', 0));
    await tester.tap(find.byKey(const Key('monitor.alert_banner.dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('monitor.alert_banner')), findsNothing);
  });

  testWidgets('sin alertas no pinta nada', (tester) async {
    await _pump(tester, cubit, events: <MonitorEvent>[_tool()]);
    expect(find.byKey(const Key('monitor.alert_banner')), findsNothing);
  });
}
