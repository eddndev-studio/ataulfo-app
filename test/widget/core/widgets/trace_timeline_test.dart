import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/widgets/trace_node.dart';
import 'package:ataulfo/core/widgets/trace_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TraceNode _n(String titulo, {TraceNodeKind kind = TraceNodeKind.tool}) =>
    TraceNode(kind: kind, titulo: titulo, icon: Icons.bolt);

Widget _host(Widget child, {bool motion = true}) => MaterialApp(
  home: Scaffold(
    body: AppMotion(
      enabled: motion,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  testWidgets('histórica: colapsada muestra el resumen y oculta los nodos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: 'Pensó · 1 paso',
        ),
      ),
    );
    expect(find.text('Pensó · 1 paso'), findsOneWidget);
    expect(find.text('Consultó los bots'), findsNothing);

    // Tocar el resumen expande: los nodos aparecen.
    await tester.tap(find.text('Pensó · 1 paso'));
    await tester.pump();
    expect(find.text('Consultó los bots'), findsOneWidget);
  });

  testWidgets('viva: expandida por defecto, con cuerpos inyectados', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
          initiallyExpanded: true,
          bodyBuilder: (_, i) => Text('cuerpo $i'),
        ),
      ),
    );
    expect(find.text('Consultó los bots'), findsOneWidget);
    expect(find.text('cuerpo 0'), findsOneWidget);
  });

  testWidgets('cap: el nodo masN «+N pasos más» se pinta', (tester) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[
            _n('paso'),
            _n('+3 pasos más', kind: TraceNodeKind.masN),
          ],
          summary: '4 pasos',
          initiallyExpanded: true,
        ),
      ),
    );
    expect(find.text('+3 pasos más'), findsOneWidget);
  });

  testWidgets('pulso presente con motion on en el último nodo', (tester) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Pensando…', kind: TraceNodeKind.thinking)],
          summary: 'Pensó',
          initiallyExpanded: true,
          pulseLast: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('trace.pulse')), findsOneWidget);
  });

  testWidgets('pulso AUSENTE con motion off', (tester) async {
    await tester.pumpWidget(
      _host(
        motion: false,
        TraceTimeline(
          nodes: <TraceNode>[_n('Pensando…', kind: TraceNodeKind.thinking)],
          summary: 'Pensó',
          initiallyExpanded: true,
          pulseLast: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('trace.pulse')), findsNothing);
  });

  testWidgets('Detener: colapsa al copy honesto y avisa onStop', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Pensando…', kind: TraceNodeKind.thinking)],
          summary: 'Pensó',
          initiallyExpanded: true,
          pulseLast: true,
          onStop: () => stopped = true,
          stopButtonKey: const Key('pa.turn_cancel'),
          stoppedSummary: 'Detenido aquí — el servidor pudo continuar',
        ),
      ),
    );
    expect(find.byKey(const Key('pa.turn_cancel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pa.turn_cancel')));
    await tester.pump();
    expect(stopped, isTrue);
    expect(
      find.text('Detenido aquí — el servidor pudo continuar'),
      findsOneWidget,
    );
    // Ya detenida, el pulso cesa.
    expect(find.byKey(const Key('trace.pulse')), findsNothing);
  });

  testWidgets('stopped externo pinta el copy honesto aunque el widget se '
      'reconstruya (el dueño del estado supo del cancel)', (tester) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
          initiallyExpanded: true,
          stopped: true,
          stoppedSummary: 'Detenido aquí — el servidor pudo continuar',
        ),
      ),
    );
    expect(
      find.text('Detenido aquí — el servidor pudo continuar'),
      findsOneWidget,
    );
    expect(find.text('Consultó los bots'), findsNothing);
    // Detenida no ofrece Detener de nuevo.
    expect(find.text('Detener'), findsNothing);
  });

  testWidgets('colapsar la traza viva NO esconde el control Detener', (
    tester,
  ) async {
    var stopped = false;
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
          initiallyExpanded: true,
          onStop: () => stopped = true,
          stopButtonKey: const Key('pa.turn_cancel'),
          stoppedSummary: 'Detenido aquí — el servidor pudo continuar',
        ),
      ),
    );
    // Colapsa tocando el encabezado.
    await tester.tap(find.text('1 paso').first);
    await tester.pump();
    expect(find.text('Consultó los bots'), findsNothing);
    // El botón sigue ahí y funciona.
    await tester.tap(find.byKey(const Key('pa.turn_cancel')));
    await tester.pump();
    expect(stopped, isTrue);
    expect(
      find.text('Detenido aquí — el servidor pudo continuar'),
      findsOneWidget,
    );
  });
}
