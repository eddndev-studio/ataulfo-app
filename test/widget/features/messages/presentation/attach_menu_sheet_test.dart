import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    void Function(AttachMenuAction?)? onResult,
    bool showCamera = false,
  }) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final r = await AttachMenuSheet.open(
                context,
                showCamera: showCamera,
              );
              onResult?.call(r);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin cámara soportada muestra SOLO Documento y Medios', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.media')), findsOneWidget);
    expect(find.text('Documento'), findsOneWidget);
    expect(find.text('Medios'), findsOneWidget);
    // Sin botones muertos: cámara sólo con soporte real; galería cuando exista.
    expect(find.byKey(const Key('attach_menu.camera')), findsNothing);
    expect(find.byKey(const Key('attach_menu.gallery')), findsNothing);
  });

  testWidgets('con cámara soportada muestra el destino Cámara', (tester) async {
    await tester.pumpWidget(host(showCamera: true));
    await openSheet(tester);

    expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.media')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.camera')), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
  });

  testWidgets('tocar Cámara cierra el sheet devolviendo camera', (
    tester,
  ) async {
    AttachMenuAction? result;
    await tester.pumpWidget(
      host(showCamera: true, onResult: (r) => result = r),
    );
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera')));
    await tester.pumpAndSettle();

    expect(result, AttachMenuAction.camera);
    expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
  });

  testWidgets('tocar Documento cierra el sheet devolviendo document', (
    tester,
  ) async {
    AttachMenuAction? result;
    var called = false;
    await tester.pumpWidget(
      host(
        onResult: (r) {
          result = r;
          called = true;
        },
      ),
    );
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('attach_menu.document')));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, AttachMenuAction.document);
    expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
  });

  testWidgets('tocar Medios cierra el sheet devolviendo media', (tester) async {
    AttachMenuAction? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('attach_menu.media')));
    await tester.pumpAndSettle();

    expect(result, AttachMenuAction.media);
    expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
  });

  testWidgets('cerrar sin elegir devuelve null', (tester) async {
    AttachMenuAction? result = AttachMenuAction.document;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openSheet(tester);
    // Descartar tocando el scrim (fuera del sheet).
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
