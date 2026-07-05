import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_expandable_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Caja acotada donde vive el panel: el sheet calcula sus fracciones contra
  // este alto y la manija traduce el arrastre en píxeles a esa fracción.
  Widget host({required AppExpandablePanel panel, double height = 600}) =>
      MaterialApp(
        theme: AppDesignTheme.dark(),
        home: Scaffold(
          body: SizedBox(height: height, width: 400, child: panel),
        ),
      );

  testWidgets('cablea el DraggableScrollableSheet con los tamaños dados', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        panel: AppExpandablePanel(
          initialSize: 0.5,
          minSize: 0.25,
          maxSize: 0.9,
          onDismissed: () {},
          builder: (context, controller) =>
              ListView(controller: controller, children: const <Widget>[]),
        ),
      ),
    );

    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    expect(sheet.expand, isFalse);
    expect(sheet.initialChildSize, 0.5);
    expect(sheet.minChildSize, 0.25);
    expect(sheet.maxChildSize, 0.9);
  });

  testWidgets('pinta la manija (con su Key) y el header fijo bajo ella', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        panel: AppExpandablePanel(
          handleKey: const Key('panel.handle'),
          onDismissed: () {},
          headerBuilder: (context, expand) =>
              const Text('cabecera', key: Key('panel.header')),
          builder: (context, controller) =>
              ListView(controller: controller, children: const <Widget>[]),
        ),
      ),
    );

    expect(find.byKey(const Key('panel.handle')), findsOneWidget);
    expect(find.byKey(const Key('panel.header')), findsOneWidget);
  });

  testWidgets('el builder recibe el ScrollController del sheet', (
    tester,
  ) async {
    ScrollController? received;
    await tester.pumpWidget(
      host(
        panel: AppExpandablePanel(
          onDismissed: () {},
          builder: (context, controller) {
            received = controller;
            return ListView(controller: controller, children: const <Widget>[]);
          },
        ),
      ),
    );

    expect(received, isNotNull);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller, same(received));
  });

  testWidgets(
    'el header expone un callback expand que agranda la hoja al máximo',
    (tester) async {
      await tester.pumpWidget(
        host(
          panel: AppExpandablePanel(
            initialSize: 0.45,
            minSize: 0.30,
            maxSize: 0.95,
            onDismissed: () {},
            headerBuilder: (context, expand) => TextButton(
              key: const Key('panel.expand'),
              onPressed: expand,
              child: const Text('expandir'),
            ),
            builder: (context, controller) =>
                ListView(controller: controller, children: const <Widget>[]),
          ),
        ),
      );

      // El sheet llena la caja; su contenido fraccional (la lista) es lo que
      // crece. Medir la lista refleja el alto real de la hoja.
      final before = tester.getSize(find.byType(ListView)).height;
      await tester.tap(find.byKey(const Key('panel.expand')));
      await tester.pumpAndSettle();
      // La hoja creció hacia arriba: su alto pasó de ~0.45 a ~0.95 del box.
      expect(tester.getSize(find.byType(ListView)).height, greaterThan(before));
    },
  );

  testWidgets('arrastrar la manija por debajo del mínimo dispara onDismissed', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      host(
        panel: AppExpandablePanel(
          handleKey: const Key('panel.handle'),
          initialSize: 0.45,
          minSize: 0.30,
          maxSize: 0.95,
          onDismissed: () => dismissed = true,
          builder: (context, controller) =>
              ListView(controller: controller, children: const <Widget>[]),
        ),
      ),
    );

    // Arrastrar la manija hacia abajo lo suficiente para cruzar el mínimo.
    await tester.drag(
      find.byKey(const Key('panel.handle')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
