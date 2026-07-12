import 'package:ataulfo/core/design/widgets/app_pill.dart';
import 'package:ataulfo/features/monitor/domain/entities/monitor_event.dart';
import 'package:ataulfo/features/monitor/presentation/cubit/monitor_live_cubit.dart';
import 'package:ataulfo/features/monitor/presentation/widgets/bot_state_pill.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MockCubit extends MockCubit<MonitorLiveState>
    implements MonitorLiveCubit {}

MonitorEvent _ev(MonitorEventKind kind) =>
    MonitorEvent(kind: kind, topic: '', at: DateTime.utc(2026, 6, 20));

const _pill = BotStatePill(botId: 'b1', chatLid: 'lid-dm');

Widget _wrap(MonitorLiveCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider<MonitorLiveCubit>.value(value: cubit, child: _pill),
  ),
);

/// Host con router: '/' pinta la pill; las rutas de drill/ejecuciones dejan un
/// marcador único (detecta un tap cableado a la URL equivocada).
Widget _wrapRouted(MonitorLiveCubit cubit) =>
    BlocProvider<MonitorLiveCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: _pill),
            ),
            GoRoute(
              path: '/bots/:botId/sessions/:chatLid/ai-log',
              builder: (_, state) => Text(
                'PAGE_AI_LOG run=${state.uri.queryParameters['run'] ?? ''}',
              ),
            ),
            GoRoute(
              path: '/bots/:botId/sessions/:chatLid/executions',
              builder: (_, _) => const Text('PAGE_EXECUTIONS'),
            ),
          ],
        ),
      ),
    );

void main() {
  late _MockCubit cubit;
  setUp(() => cubit = _MockCubit());

  void stub(MonitorLiveState state) => whenListen(
    cubit,
    const Stream<MonitorLiveState>.empty(),
    initialState: state,
  );

  testWidgets('turno activo ⇒ píldora "Pensando"', (tester) async {
    stub(
      MonitorLiveState(events: <MonitorEvent>[_ev(MonitorEventKind.aiTool)]),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsOneWidget);
    expect(find.textContaining('Pensando'), findsOneWidget);
  });

  testWidgets('fallo de corrida retenido ⇒ píldora con el copy es-MX del '
      'error (jamás el crudo)', (tester) async {
    stub(
      const MonitorLiveState(
        failure: MonitorFailure(
          isFlow: false,
          runId: 'r1',
          error: 'context deadline exceeded',
        ),
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsOneWidget);
    expect(find.text('La corrida excedió el tiempo límite.'), findsOneWidget);
    expect(find.textContaining('deadline'), findsNothing);
  });

  testWidgets('tap en el fallo de corrida abre el drill de ESA corrida '
      '(?run=)', (tester) async {
    stub(
      const MonitorLiveState(
        failure: MonitorFailure(isFlow: false, runId: 'r1', error: 'boom'),
      ),
    );
    await tester.pumpWidget(_wrapRouted(cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('monitor.bot_state_pill')));
    await tester.pumpAndSettle();
    expect(find.text('PAGE_AI_LOG run=r1'), findsOneWidget);
  });

  testWidgets('fallo de FLUJO (sin runId) ⇒ copy propio y tap a Ejecuciones '
      '(degradación definida: no promete traza)', (tester) async {
    stub(
      const MonitorLiveState(
        failure: MonitorFailure(isFlow: true, runId: '', error: 'paso roto'),
      ),
    );
    await tester.pumpWidget(_wrapRouted(cubit));
    await tester.pumpAndSettle();
    expect(find.text('Falló una ejecución de flujo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('monitor.bot_state_pill')));
    await tester.pumpAndSettle();
    expect(find.text('PAGE_EXECUTIONS'), findsOneWidget);
  });

  testWidgets('turno completado OK (sin fallo retenido) ⇒ sin píldora', (
    tester,
  ) async {
    stub(const MonitorLiveState());
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsNothing);
  });

  testWidgets('la píldora es un AppPill del kit con dot de estado', (
    tester,
  ) async {
    stub(
      MonitorLiveState(events: <MonitorEvent>[_ev(MonitorEventKind.aiTool)]),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
    // Anatomía del kit, no una cápsula a mano: mismo padding/tipografía que
    // cualquier otra pill de la app, con el dot como indicador de estado.
    expect(
      tester.widget(find.byKey(const Key('monitor.bot_state_pill'))),
      isA<AppPill>(),
    );
    expect(find.byKey(const ValueKey<String>('app_pill.dot')), findsOneWidget);
  });

  testWidgets('turno colgado (stalled) ⇒ sin píldora aunque haya actividad', (
    tester,
  ) async {
    stub(
      MonitorLiveState(
        events: <MonitorEvent>[_ev(MonitorEventKind.aiTool)],
        stalled: true,
      ),
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump();
    expect(find.byKey(const Key('monitor.bot_state_pill')), findsNothing);
  });
}
