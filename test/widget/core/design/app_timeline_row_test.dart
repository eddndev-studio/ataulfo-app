import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_timeline_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(body: child),
  );

  group('AppTimelineRow — índice, badge y child', () {
    testWidgets('pinta el índice 1-based en el bullet y el child al frente', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AppTimelineRow(index: 2, child: Text('contenido'))),
      );

      expect(find.byKey(const Key('app_timeline_row.bullet')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('el badge (pill de rama) se monta encima del child', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppTimelineRow(
            index: 0,
            badge: Text('si cumple'),
            child: Text('contenido'),
          ),
        ),
      );

      expect(find.text('si cumple'), findsOneWidget);
      final badgeY = tester.getCenter(find.text('si cumple')).dy;
      final childY = tester.getCenter(find.text('contenido')).dy;
      expect(badgeY, lessThan(childY));
    });
  });

  group('AppTimelineRow — handle de reorder', () {
    testWidgets(
      'con dragIndex monta el handle 48x48 con Semantics "Mover paso"',
      (tester) async {
        await tester.pumpWidget(
          host(
            const AppTimelineRow(
              index: 0,
              dragIndex: 0,
              dragHandleKey: Key('t.handle'),
              child: Text('contenido'),
            ),
          ),
        );

        final handle = find.byKey(const Key('t.handle'));
        expect(handle, findsOneWidget);
        final size = tester.getSize(
          find.ancestor(of: handle, matching: find.byType(SizedBox)).first,
        );
        expect(size.width, 48);
        expect(size.height, 48);
        expect(find.bySemanticsLabel('Mover paso'), findsOneWidget);
      },
    );

    testWidgets('sin dragIndex no hay handle', (tester) async {
      await tester.pumpWidget(
        host(const AppTimelineRow(index: 0, child: Text('contenido'))),
      );

      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });
  });

  group('AppTimelineRow — highlight del paso recién llegado', () {
    testWidgets('highlighted:true monta el glow one-shot', (tester) async {
      await tester.pumpWidget(
        host(
          const AppTimelineRow(
            index: 0,
            highlighted: true,
            child: Text('contenido'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('app_timeline_row.highlight')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('sin highlight no hay glow', (tester) async {
      await tester.pumpWidget(
        host(const AppTimelineRow(index: 0, child: Text('contenido'))),
      );

      expect(find.byKey(const Key('app_timeline_row.highlight')), findsNothing);
    });
  });
}
