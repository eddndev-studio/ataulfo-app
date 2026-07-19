import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/monitor/presentation/widgets/live_activity.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCubit extends MockCubit<MonitorLiveState>
    implements MonitorLiveCubit {}

MonitorEvent _ev(
  MonitorEventKind kind, {
  String toolName = '',
  int iteration = 0,
}) => MonitorEvent(
  kind: kind,
  topic: '',
  at: DateTime.utc(2026, 6, 20),
  toolName: toolName,
  iteration: iteration,
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

  Future<void> pump(
    WidgetTester tester, {
    List<MonitorEvent> events = const <MonitorEvent>[],
    bool reconnecting = false,
    bool stalled = false,
  }) async {
    whenListen(
      cubit,
      const Stream<MonitorLiveState>.empty(),
      initialState: MonitorLiveState(
        events: events,
        reconnecting: reconnecting,
        stalled: stalled,
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
  }

  testWidgets(
    'turno activo: mini-traza COLAPSADA con el resumen humano (jamás el '
    'nombre crudo del tool)',
    (tester) async {
      await pump(
        tester,
        events: <MonitorEvent>[
          _ev(MonitorEventKind.aiTurn, iteration: 1),
          _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
        ],
      );

      expect(find.byKey(const Key('monitor.live_activity')), findsOneWidget);
      expect(find.text('Consultó los Canales · 1 paso'), findsOneWidget);
      expect(find.textContaining('list_bots'), findsNothing);
      // Colapsada por default: el carril (nodo thinking) aún no se pinta.
      expect(find.text('Pensando…'), findsNothing);
    },
  );

  testWidgets('tocar el resumen expande la timeline con carril y latido', (
    tester,
  ) async {
    await pump(
      tester,
      events: <MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, iteration: 1),
        _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
      ],
    );

    await tester.tap(find.byKey(const Key('monitor.live_activity')));
    await tester.pump();

    // Nodos solo-nombre de la gramática viva + el pulso en el paso actual.
    expect(find.text('Pensando…'), findsOneWidget);
    expect(find.text('Consultó los Canales'), findsOneWidget);
    expect(find.byKey(const Key('trace.pulse')), findsOneWidget);
    // Altura acotada: el carril vive dentro de un scroll interno.
    expect(find.byKey(const Key('monitor.live_trace.scroll')), findsOneWidget);
  });

  testWidgets('cap VIVO: con más de 8 pasos sobrevive la cola (el paso '
      'actual late) y los viejos se anuncian al inicio', (tester) async {
    final events = <MonitorEvent>[
      _ev(MonitorEventKind.aiTurn, iteration: 1),
      for (var i = 0; i < 9; i++)
        _ev(MonitorEventKind.aiTool, toolName: 'tool_$i'),
    ];
    await pump(tester, events: events);
    await tester.tap(find.byKey(const Key('monitor.live_activity')));
    await tester.pump();

    // 10 nodos reales ⇒ «+3 pasos anteriores» + los 7 últimos.
    expect(find.text('+3 pasos anteriores'), findsOneWidget);
    expect(find.text('Usó tool_8'), findsOneWidget); // el actual, visible
    expect(find.text('Usó tool_0'), findsNothing); // el viejo, recortado
  });

  testWidgets('turno terminado (lista vacía tras el terminal) oculta el '
      'footer', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });

  testWidgets('reconnecting ⇒ "Reconectando…" (prioritario sobre actividad)', (
    tester,
  ) async {
    await pump(
      tester,
      events: <MonitorEvent>[_ev(MonitorEventKind.aiTool, toolName: 'x')],
      reconnecting: true,
    );

    expect(find.byKey(const Key('monitor.sse_health')), findsOneWidget);
    expect(find.textContaining('Reconectando'), findsOneWidget);
    expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
  });

  testWidgets('la actividad en vivo se expone a accesibilidad (live region)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      events: <MonitorEvent>[
        _ev(MonitorEventKind.aiTurn, iteration: 1),
        _ev(MonitorEventKind.aiTool, toolName: 'list_bots'),
      ],
    );

    // El wrapper Semantics(liveRegion) expone el resumen legible al lector.
    expect(
      find.bySemanticsLabel('Consultó los Canales · 1 paso'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets(
    'turno colgado (stalled) oculta el footer aunque haya actividad',
    (tester) async {
      await pump(
        tester,
        events: <MonitorEvent>[_ev(MonitorEventKind.aiTool, toolName: 'x')],
        stalled: true,
      );

      expect(find.byKey(const Key('monitor.live_activity')), findsNothing);
    },
  );
}
