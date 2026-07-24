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

  group('showAppBottomSheet — guard de descarte (confirmDiscard)', () {
    /// Abre una hoja guardada y devuelve su Future de resultado.
    Future<Future<String?>> openGuarded(
      WidgetTester tester, {
      required bool Function() confirmDiscard,
      bool Function()? canDismiss,
      bool showDragHandle = true,
    }) async {
      setTopInset(tester, 0);
      late Future<String?> result;
      await tester.pumpWidget(
        host(
          (context) => result = showAppBottomSheet<String>(
            context,
            isScrollControlled: true,
            confirmDiscard: confirmDiscard,
            canDismiss: canDismiss,
            showDragHandle: showDragHandle,
            builder: (sheetContext) => SizedBox(
              key: const Key('sheet'),
              height: 300,
              child: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop('guardado'),
                  child: const Text('guardar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('sin cambios (callback false): el scrim cierra directo', (
      tester,
    ) async {
      final result = await openGuarded(tester, confirmDiscard: () => false);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('con cambios: el scrim pide confirmación y cancelar conserva '
        'la hoja', (tester) async {
      await openGuarded(tester, confirmDiscard: () => true);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);

      await tester.tap(find.byKey(appSheetDiscardCancelKey));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(find.byKey(const Key('sheet')), findsOneWidget);
    });

    testWidgets('con cambios: confirmar el descarte cierra con null', (
      tester,
    ) async {
      final result = await openGuarded(tester, confirmDiscard: () => true);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(appSheetDiscardConfirmKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('el back físico también pasa por el guard', (tester) async {
      await openGuarded(tester, confirmDiscard: () => true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      expect(find.byKey(const Key('sheet')), findsOneWidget);
    });

    testWidgets('canDismiss false bloquea scrim y back sin pedir descarte', (
      tester,
    ) async {
      await openGuarded(
        tester,
        confirmDiscard: () => true,
        canDismiss: () => false,
      );

      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sheet')), findsOneWidget);
      expect(find.text('¿Descartar los cambios?'), findsNothing);
    });

    testWidgets('arrastrar el handle hacia abajo pasa por el guard', (
      tester,
    ) async {
      await openGuarded(tester, confirmDiscard: () => true);
      expect(find.byKey(appSheetDragHandleKey), findsOneWidget);

      await tester.drag(
        find.byKey(appSheetDragHandleKey),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      expect(find.byKey(const Key('sheet')), findsOneWidget);
    });

    testWidgets('arrastrar el handle sin cambios cierra directo', (
      tester,
    ) async {
      final result = await openGuarded(tester, confirmDiscard: () => false);
      await tester.drag(
        find.byKey(appSheetDragHandleKey),
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sheet')), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('showDragHandle false: la hoja guardada no pinta handle', (
      tester,
    ) async {
      await openGuarded(
        tester,
        confirmDiscard: () => true,
        showDragHandle: false,
      );
      expect(find.byKey(appSheetDragHandleKey), findsNothing);
    });

    testWidgets('el cierre programático (guardar) NO pasa por el guard', (
      tester,
    ) async {
      // El guard intercepta DESCARTES; un pop explícito con resultado es el
      // camino feliz del formulario y debe entregar su valor sin diálogo.
      final result = await openGuarded(tester, confirmDiscard: () => true);
      await tester.tap(find.text('guardar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar los cambios?'), findsNothing);
      expect(await result, 'guardado');
    });
  });
}
