import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_camera_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({void Function(CameraCaptureMode?)? onResult}) => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final r = await AttachCameraSheet.open(context);
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

  testWidgets('muestra las dos filas: Tomar foto y Grabar video', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    expect(find.byKey(const Key('attach_menu.camera.photo')), findsOneWidget);
    expect(find.byKey(const Key('attach_menu.camera.video')), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Grabar video'), findsOneWidget);
  });

  testWidgets('tocar Tomar foto cierra devolviendo photo', (tester) async {
    CameraCaptureMode? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera.photo')));
    await tester.pumpAndSettle();

    expect(result, CameraCaptureMode.photo);
    expect(find.byKey(const Key('attach_camera_sheet')), findsNothing);
  });

  testWidgets('tocar Grabar video cierra devolviendo video', (tester) async {
    CameraCaptureMode? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('attach_menu.camera.video')));
    await tester.pumpAndSettle();

    expect(result, CameraCaptureMode.video);
  });

  testWidgets('cerrar sin elegir devuelve null', (tester) async {
    CameraCaptureMode? result = CameraCaptureMode.photo;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await openSheet(tester);
    // Descartar tocando el scrim (fuera del sheet).
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
