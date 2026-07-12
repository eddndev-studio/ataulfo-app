import 'package:ataulfo/core/design/motion.dart';
import 'package:ataulfo/core/design/widgets/app_thread_event_card.dart';
import 'package:ataulfo/core/widgets/trace_node.dart';
import 'package:ataulfo/core/widgets/trace_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TraceNode _n(String titulo, {TraceNodeKind kind = TraceNodeKind.tool}) =>
    TraceNode(kind: kind, titulo: titulo, icon: Icons.bolt);

Widget _host(Widget child, {bool motion = true, double width = 360}) =>
    MaterialApp(
      home: Scaffold(
        body: AppMotion(
          enabled: motion,
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );

/// El `Align` raíz de la tarjeta del evento (el que decide centrado vs pegado
/// al área de mensaje). En una tarjeta COLAPSADA es el único `Align` bajo la
/// [AppThreadEventCard].
Align _cardAlign(WidgetTester tester) => tester.widget<Align>(
  find
      .descendant(
        of: find.byType(AppThreadEventCard),
        matching: find.byType(Align),
      )
      .first,
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

  testWidgets('stretch: la tarjeta se pega al área de mensaje (no centrada) y '
      'llena el ancho de la columna, colapsada y expandida', (tester) async {
    Widget subject({required bool expanded}) => _host(
      width: 360,
      TraceTimeline(
        nodes: <TraceNode>[_n('Consultó los bots')],
        summary: '1 paso',
        stretch: true,
        initiallyExpanded: expanded,
      ),
    );

    // Colapsada: alineada a la izquierda y a todo el ancho de la columna.
    await tester.pumpWidget(subject(expanded: false));
    expect(_cardAlign(tester).alignment, Alignment.centerLeft);
    final box = find.descendant(
      of: find.byType(AppThreadEventCard),
      matching: find.byType(Container),
    );
    final collapsedWidth = tester.getSize(box.first).width;
    expect(collapsedWidth, moreOrLessEquals(360, epsilon: 1));

    // Expandida: MISMO ancho (sin recálculo brusco al abrir).
    await tester.pumpWidget(subject(expanded: true));
    await tester.pumpAndSettle();
    expect(_cardAlign(tester).alignment, Alignment.centerLeft);
    expect(
      tester.getSize(box.first).width,
      moreOrLessEquals(collapsedWidth, epsilon: 1),
    );
  });

  testWidgets('sin stretch: la tarjeta sigue centrada y abraza el contenido', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 360,
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
        ),
      ),
    );
    expect(_cardAlign(tester).alignment, Alignment.center);
    final box = find.descendant(
      of: find.byType(AppThreadEventCard),
      matching: find.byType(Container),
    );
    // Abraza el contenido: bastante menos que la columna de 360.
    expect(tester.getSize(box.first).width, lessThan(300));
  });

  testWidgets('apertura animada: AnimatedSize envuelve la traza; con motion '
      'off su duración colapsa a cero', (tester) async {
    await tester.pumpWidget(
      _host(
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
        ),
      ),
    );
    expect(find.byType(AnimatedSize), findsWidgets);
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration,
      greaterThan(Duration.zero),
    );

    await tester.pumpWidget(
      _host(
        motion: false,
        TraceTimeline(
          nodes: <TraceNode>[_n('Consultó los bots')],
          summary: '1 paso',
        ),
      ),
    );
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration,
      Duration.zero,
    );
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
