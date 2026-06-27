import 'package:ataulfo/core/design/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // El inset superior va en la vista de prueba, no en un MediaQuery anidado:
  // la hoja se monta en una ruta del Navigator raíz, por encima de `home`, así
  // que un MediaQuery envuelto en `home` jamás la alcanzaría.
  void setTopInset(WidgetTester tester, double top) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = FakeViewPadding(top: top);
    addTearDown(tester.view.reset);
  }

  Widget host(void Function(BuildContext) onTap) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'una hoja con contenido alto no pinta detrás de la barra de estado',
    (tester) async {
      setTopInset(tester, 50);
      await tester.pumpWidget(
        host(
          (context) => showAppBottomSheet<void>(
            context,
            isScrollControlled: true,
            builder: (_) => Container(
              key: const Key('sheet'),
              // Más alto que la pantalla: sin área segura crecería hasta y=0.
              height: 2000,
              color: const Color(0xFF112233),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // El borde superior de la hoja queda en o por debajo del inset (50), no
      // detrás de la barra de estado.
      final top = tester.getTopLeft(find.byKey(const Key('sheet'))).dy;
      expect(top, greaterThanOrEqualTo(50.0));
    },
  );

  testWidgets('reenvía el backgroundColor al modal', (tester) async {
    setTopInset(tester, 0);
    await tester.pumpWidget(
      host(
        (context) => showAppBottomSheet<void>(
          context,
          backgroundColor: const Color(0xFF010203),
          builder: (_) =>
              const SizedBox(key: Key('sheet'), height: 100, width: 100),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('sheet')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, const Color(0xFF010203));
  });

  testWidgets('la hoja trae drag handle y es arrastrable para descartar', (
    tester,
  ) async {
    setTopInset(tester, 0);
    await tester.pumpWidget(
      host(
        (context) => showAppBottomSheet<void>(
          context,
          isScrollControlled: true,
          builder: (_) => const SizedBox(key: Key('sheet'), height: 100),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // El SingleChildScrollView de las hojas se come el gesto vertical; el
    // drag handle es la zona dedicada para arrastrar y cerrar. enableDrag
    // queda en su default (true) para que ese arrastre descarte.
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.showDragHandle, isTrue);
    expect(sheet.enableDrag, isTrue);
  });
}
