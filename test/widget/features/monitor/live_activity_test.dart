import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/monitor/presentation/widgets/live_activity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCubit extends MockCubit<MonitorLiveState>
    implements MonitorLiveCubit {}

MonitorEvent _ev(MonitorEventKind kind, {String toolName = ''}) => MonitorEvent(
  kind: kind,
  topic: '',
  at: DateTime.utc(2026, 6, 20),
  toolName: toolName,
);

Widget _wrap(MonitorLiveCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<MonitorLiveCubit>.value(
      value: cubit,
      child: const LiveActivity(),
    ),
  ),
);

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  testWidgets('turno activo (aiTool) muestra typing + el tool en uso', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: <MonitorEvent>[
          _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    expect(find.byKey(const Key('monitor.live_activity')), findsOneWidget);
    expect(find.textContaining('list_bots'), findsOneWidget);
  });

  testWidgets('turno terminado (aiCompleted) oculta el footer', (tester) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: <MonitorEvent>[
          _ev(MonitorEventKind.aiTool, toolName: 'x'),
          _ev(MonitorEventKind.aiCompleted),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });

  testWidgets('reconnecting ⇒ "Reconectando…" (prioritario sobre actividad)', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: <MonitorEvent>[_ev(MonitorEventKind.aiTool, toolName: 'x')],
        reconnecting: true,
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    expect(find.byKey(const Key('monitor.sse_health')), findsOneWidget);
    expect(find.textContaining('Reconectando'), findsOneWidget);
    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });

  testWidgets('la actividad en vivo se expone a accesibilidad (live region)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: <MonitorEvent>[
          _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
        ],
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    // El wrapper Semantics(liveRegion) expone la etiqueta legible al lector.
    expect(find.bySemanticsLabel('Usando list_bots…'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('sin eventos (no admin / idle) no pinta nada', (tester) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: const MonitorLiveState(),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });

  testWidgets('turno colgado (stalled) oculta el footer aunque el último sea activo', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: <MonitorEvent>[_ev(MonitorEventKind.aiTool, toolName: 'x')],
        stalled: true,
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();

    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });
}
