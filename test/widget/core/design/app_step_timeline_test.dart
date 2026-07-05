import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_step_timeline.dart';
import 'package:ataulfo/core/design/widgets/app_timeline_jump.dart';
import 'package:ataulfo/core/design/widgets/app_timeline_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required int itemCount,
    void Function(int from, int to)? onReorder,
    bool Function(int from, int to)? canReorder,
    void Function(int index)? onInsertAt,
    List<TimelineJump> jumps = const <TimelineJump>[],
    Widget? header,
    Widget? footer,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: AppStepTimeline(
        itemCount: itemCount,
        itemKey: (i) => ValueKey<String>('item.$i'),
        itemBuilder: (_, i) => AppTimelineRow(
          index: i,
          spineBelow: i < itemCount - 1,
          dragIndex: itemCount >= 2 ? i : null,
          dragHandleKey: Key('t.handle.$i'),
          child: SizedBox(height: 60, child: Text('fila $i')),
        ),
        onReorder: onReorder,
        canReorder: canReorder,
        onInsertAt: onInsertAt,
        insertEndKey: const Key('t.insert.end'),
        jumps: jumps,
        header: header,
        footer: footer,
      ),
    ),
  );

  group('AppStepTimeline — estructura', () {
    testWidgets('pinta una fila indexada por item, con header y footer '
        'dentro del scroll', (tester) async {
      await tester.pumpWidget(
        host(
          itemCount: 3,
          onReorder: (_, _) {},
          header: const Text('encabezado'),
          footer: const Text('pie'),
        ),
      );

      expect(find.text('encabezado'), findsOneWidget);
      expect(find.text('pie'), findsOneWidget);
      expect(find.text('fila 0'), findsOneWidget);
      expect(find.text('fila 2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('con 1 solo item no monta ReorderableListView (nada que '
        'reordenar)', (tester) async {
      await tester.pumpWidget(host(itemCount: 1, onReorder: (_, _) {}));

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.text('fila 0'), findsOneWidget);
    });

    testWidgets('sin onReorder monta la lista simple aunque haya varios '
        'items', (tester) async {
      await tester.pumpWidget(host(itemCount: 3));

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.text('fila 2'), findsOneWidget);
    });
  });

  group('AppStepTimeline — reorder validado antes del drop', () {
    testWidgets('un drop permitido llama canReorder y luego onReorder con '
        'índices ya ajustados', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        host(
          itemCount: 3,
          canReorder: (from, to) {
            calls.add('can $from->$to');
            return true;
          },
          onReorder: (from, to) => calls.add('re $from->$to'),
        ),
      );

      await tester.timedDrag(
        find.byKey(const Key('t.handle.0')),
        const Offset(0, 90),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(calls, <String>['can 0->1', 're 0->1']);
    });

    testWidgets('canReorder false ⇒ el drop NO llama onReorder (la fila '
        'revierte sola)', (tester) async {
      final reorders = <String>[];
      await tester.pumpWidget(
        host(
          itemCount: 3,
          canReorder: (_, _) => false,
          onReorder: (from, to) => reorders.add('$from->$to'),
        ),
      );

      await tester.timedDrag(
        find.byKey(const Key('t.handle.0')),
        const Offset(0, 90),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      expect(reorders, isEmpty);
      // La lista sigue en su orden original.
      final y0 = tester.getTopLeft(find.text('fila 0')).dy;
      final y1 = tester.getTopLeft(find.text('fila 1')).dy;
      expect(y0, lessThan(y1));
    });
  });

  group('AppStepTimeline — inserción posicional', () {
    testWidgets('monta zonas "+" ENTRE filas y el inserter del final '
        'siempre visible', (tester) async {
      final inserts = <int>[];
      await tester.pumpWidget(
        host(itemCount: 3, onReorder: (_, _) {}, onInsertAt: inserts.add),
      );

      // Entre filas: tras la fila 0 (inserta en 1) y tras la 1 (inserta en 2).
      expect(
        find.byKey(const Key('app_step_timeline.insert.1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('app_step_timeline.insert.2')),
        findsOneWidget,
      );
      // Ni antes de la primera ni tras la última (esa es el inserter final).
      expect(find.byKey(const Key('app_step_timeline.insert.0')), findsNothing);
      expect(find.byKey(const Key('app_step_timeline.insert.3')), findsNothing);
      expect(find.byKey(const Key('t.insert.end')), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_step_timeline.insert.1')));
      await tester.tap(find.byKey(const Key('t.insert.end')));
      expect(inserts, <int>[1, 3]);
    });

    testWidgets('sin onInsertAt no hay zonas ni inserter final', (
      tester,
    ) async {
      await tester.pumpWidget(host(itemCount: 3, onReorder: (_, _) {}));

      expect(find.byKey(const Key('app_step_timeline.insert.1')), findsNothing);
      expect(find.byKey(const Key('t.insert.end')), findsNothing);
    });

    testWidgets('con 1 item el inserter final sigue visible', (tester) async {
      final inserts = <int>[];
      await tester.pumpWidget(
        host(itemCount: 1, onReorder: (_, _) {}, onInsertAt: inserts.add),
      );

      await tester.tap(find.byKey(const Key('t.insert.end')));
      expect(inserts, <int>[1]);
    });
  });

  group('AppStepTimeline — saltos de rama', () {
    testWidgets('cada salto pinta su pill de llegada con el label en la '
        'fila destino', (tester) async {
      await tester.pumpWidget(
        host(
          itemCount: 4,
          onReorder: (_, _) {},
          jumps: const <TimelineJump>[
            TimelineJump(from: 0, to: 2, label: 'si cumple'),
            TimelineJump(from: 0, to: 3, label: 'si no'),
          ],
        ),
      );

      final match = find.text('si cumple');
      final else_ = find.text('si no');
      expect(match, findsOneWidget);
      expect(else_, findsOneWidget);
      // Cada pill vive junto a su fila destino: "si cumple" por encima de la
      // fila 2 y "si no" por encima de la 3.
      expect(
        tester.getCenter(match).dy,
        lessThan(tester.getTopLeft(find.text('fila 2')).dy),
      );
      expect(
        tester.getCenter(else_).dy,
        lessThan(tester.getTopLeft(find.text('fila 3')).dy),
      );
      expect(tester.getCenter(match).dy, lessThan(tester.getCenter(else_).dy));
    });

    testWidgets('sin saltos no se reserva margen de gutter', (tester) async {
      await tester.pumpWidget(host(itemCount: 2, onReorder: (_, _) {}));
      final x = tester.getTopLeft(find.text('fila 0')).dx;

      await tester.pumpWidget(
        host(
          itemCount: 2,
          onReorder: (_, _) {},
          jumps: const <TimelineJump>[
            TimelineJump(from: 0, to: 1, label: 'si cumple'),
          ],
        ),
      );
      final xWithJumps = tester.getTopLeft(find.text('fila 0')).dx;

      expect(xWithJumps, greaterThan(x));
    });
  });

  group('timelineJumpLanes — carriles sin ensalada', () {
    test('saltos que se solapan (mismo origen) reciben carriles distintos', () {
      const jumps = <TimelineJump>[
        TimelineJump(from: 0, to: 2, label: 'a'),
        TimelineJump(from: 0, to: 4, label: 'b'),
      ];
      expect(timelineJumpLanes(jumps), <int>[0, 1]);
    });

    test('saltos disjuntos comparten el carril 0', () {
      const jumps = <TimelineJump>[
        TimelineJump(from: 0, to: 1, label: 'a'),
        TimelineJump(from: 3, to: 5, label: 'b'),
      ];
      expect(timelineJumpLanes(jumps), <int>[0, 0]);
    });

    test('tres saltos encadenados usan el mínimo de carriles', () {
      const jumps = <TimelineJump>[
        TimelineJump(from: 0, to: 2, label: 'a'),
        TimelineJump(from: 1, to: 3, label: 'b'),
        TimelineJump(from: 2, to: 4, label: 'c'),
      ];
      // a y b se solapan; c se solapa con ambos en sus extremos compartidos
      // (2 y 4-3) — pero c NO se solapa con a más que en el punto 2, que
      // cuenta como solape (comparten fila).
      expect(timelineJumpLanes(jumps), <int>[0, 1, 2]);
    });
  });
}
