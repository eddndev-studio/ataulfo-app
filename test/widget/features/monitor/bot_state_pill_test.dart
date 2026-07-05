import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/monitor/presentation/widgets/bot_state_pill.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockCubit extends MockCubit<MonitorLiveState>
    implements MonitorLiveCubit {}

MonitorEvent _ev(MonitorEventKind kind) =>
    MonitorEvent(kind: kind, topic: '', at: DateTime.utc(2026, 6, 20));

Widget _wrap(MonitorLiveCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<MonitorLiveCubit>.value(
      value: cubit,
      child: const BotStatePill(),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  _MockCubit cubit,
  List<MonitorEvent> events,
) async {
  whenListen(
    cubit,
    const Stream<MonitorLiveState>.empty(),
    initialState: MonitorLiveState(events: events),
  );
  await tester.pumpWidget(_wrap(cubit));
  await tester.pump();
}

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  testWidgets('turno activo ⇒ píldora "Pensando"', (tester) async {
    await _pump(tester, cubit, <MonitorEvent>[_ev(MonitorEventKind.aiTool)]);
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsOneWidget);
    expect(find.textContaining('Pensando'), findsOneWidget);
  });

  testWidgets('última corrida fallida ⇒ píldora de error', (tester) async {
    await _pump(tester, cubit, <MonitorEvent>[
      _ev(MonitorEventKind.aiTool),
      _ev(MonitorEventKind.aiFailed),
    ]);
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsOneWidget);
    expect(find.textContaining('Falló'), findsOneWidget);
  });

  testWidgets('turno completado OK ⇒ sin píldora', (tester) async {
    await _pump(tester, cubit, <MonitorEvent>[
      _ev(MonitorEventKind.aiTool),
      _ev(MonitorEventKind.aiCompleted),
    ]);
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsNothing);
  });

  testWidgets('sin eventos ⇒ sin píldora', (tester) async {
    await _pump(tester, cubit, <MonitorEvent>[]);
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsNothing);
  });

  testWidgets('la píldora es un AppPill del kit con dot de estado', (
    tester,
  ) async {
    await _pump(tester, cubit, <MonitorEvent>[_ev(MonitorEventKind.aiTool)]);
    // Anatomía del kit, no una cápsula a mano: mismo padding/tipografía que
    // cualquier otra pill de la app, con el dot como indicador de estado.
    expect(
      tester.widget(find.byKey(const Key('monitor.bot_state_pill'))),
      isA<AppPill>(),
    );
    expect(find.byKey(const ValueKey<String>('app_pill.dot')), findsOneWidget);
  });

  testWidgets(
    'turno colgado (stalled) ⇒ sin píldora aunque el último sea activo',
    (tester) async {
      whenListen(
        cubit,
        const Stream<MonitorLiveState>.empty(),
        initialState: MonitorLiveState(
          events: <MonitorEvent>[_ev(MonitorEventKind.aiTool)],
          stalled: true,
        ),
      );
      await tester.pumpWidget(_wrap(cubit));
      await tester.pump();
      expect(find.byKey(const Key('monitor.bot_state_pill')), findsNothing);
    },
  );
}
