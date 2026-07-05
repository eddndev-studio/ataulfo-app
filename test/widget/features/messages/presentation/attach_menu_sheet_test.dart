import 'dart:typed_data';

import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/features/media/domain/repositories/device_gallery_port.dart';
import 'package:ataulfo/features/media/domain/repositories/media_file_picker.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_gallery_sheet.dart';
import 'package:ataulfo/features/messages/presentation/widgets/attach_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carrete falso: N assets fijos, miniaturas/bytes triviales. Suficiente para
/// pintar la grilla y confirmar selecciones sin plataforma.
class _FakeGallery implements DeviceGalleryPort {
  _FakeGallery(this.assets);

  final List<DeviceMediaAsset> assets;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<List<DeviceMediaAsset>> recentMedia({int limit = 60}) async =>
      assets.take(limit).toList(growable: false);

  @override
  Future<Uint8List?> thumbnailFor(DeviceMediaAsset asset, {int size = 256}) =>
      Future<Uint8List?>.value();

  @override
  Future<PickedMedia?> bytesFor(DeviceMediaAsset asset) async => PickedMedia(
    bytes: Uint8List.fromList(<int>[1]),
    filename: asset.filename,
  );
}

const List<DeviceMediaAsset> _threeAssets = <DeviceMediaAsset>[
  DeviceMediaAsset(id: 'a1', filename: 'uno.jpg'),
  DeviceMediaAsset(
    id: 'a2',
    filename: 'dos.mp4',
    isVideo: true,
    durationMs: 62000,
  ),
  DeviceMediaAsset(id: 'a3', filename: 'tres.png'),
];

void main() {
  // Superficie tipo teléfono: el sheet expandible calcula fracciones de alto
  // y la grilla debe dejar la primera fila completamente tappeable.
  const Size phone = Size(1080, 2340);
  const double dpr = 3.0;

  Widget host({
    void Function(AttachMenuResult?)? onResult,
    bool showCamera = false,
    DeviceGalleryPort? gallery,
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
                gallery: gallery,
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

  group('sin galería (carrete no soportado)', () {
    testWidgets('sin cámara soportada muestra SOLO Documento y Medios', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await openSheet(tester);

      expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
      expect(find.byKey(const Key('attach_menu.media')), findsOneWidget);
      expect(find.text('Documento'), findsOneWidget);
      expect(find.text('Medios'), findsOneWidget);
      // Sin botones muertos: cámara y galería sólo con soporte real.
      expect(find.byKey(const Key('attach_menu.camera')), findsNothing);
      expect(find.byKey(const Key('attach_menu.gallery')), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets('con cámara soportada muestra el destino Cámara', (
      tester,
    ) async {
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
      AttachMenuResult? result;
      await tester.pumpWidget(
        host(showCamera: true, onResult: (r) => result = r),
      );
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('attach_menu.camera')));
      await tester.pumpAndSettle();

      expect(result, isA<AttachMenuDestination>());
      expect(
        (result! as AttachMenuDestination).action,
        AttachMenuAction.camera,
      );
      expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
    });

    testWidgets('tocar Documento cierra el sheet devolviendo document', (
      tester,
    ) async {
      AttachMenuResult? result;
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
      expect(
        (result! as AttachMenuDestination).action,
        AttachMenuAction.document,
      );
      expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
    });

    testWidgets('tocar Medios cierra el sheet devolviendo media', (
      tester,
    ) async {
      AttachMenuResult? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('attach_menu.media')));
      await tester.pumpAndSettle();

      expect((result! as AttachMenuDestination).action, AttachMenuAction.media);
      expect(find.byKey(const Key('attach_menu_sheet')), findsNothing);
    });

    testWidgets('cerrar sin elegir devuelve null', (tester) async {
      AttachMenuResult? result = const AttachMenuDestination(
        AttachMenuAction.document,
      );
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openSheet(tester);
      // Descartar tocando el scrim (fuera del sheet).
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('con galería (carrete soportado)', () {
    setUp(() {
      // Nada: cada test configura su superficie.
    });

    Future<void> pumpPhone(
      WidgetTester tester, {
      required Widget widget,
    }) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(widget);
    }

    testWidgets(
      'el sheet expandible ofrece el grid de íconos + la grilla de recientes',
      (tester) async {
        await pumpPhone(
          tester,
          widget: host(gallery: _FakeGallery(_threeAssets), showCamera: true),
        );
        await openSheet(tester);

        // Grid de íconos arriba (incluye Galería) y la previsualización del
        // carrete debajo, visible SIN taps adicionales.
        expect(find.byKey(const Key('attach_menu.document')), findsOneWidget);
        expect(find.byKey(const Key('attach_menu.media')), findsOneWidget);
        expect(find.byKey(const Key('attach_menu.camera')), findsOneWidget);
        expect(find.byKey(const Key('attach_menu.gallery')), findsOneWidget);
        expect(find.byKey(const Key('attach_gallery.grid')), findsOneWidget);
        expect(find.byKey(const Key('attach_gallery.item.a1')), findsOneWidget);
        expect(find.byKey(const Key('attach_gallery.item.a2')), findsOneWidget);
        expect(find.byKey(const Key('attach_gallery.item.a3')), findsOneWidget);
      },
    );

    testWidgets('la presentación es un DraggableScrollableSheet expandible', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        widget: host(gallery: _FakeGallery(_threeAssets)),
      );
      await openSheet(tester);

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.expand, isFalse);
      expect(sheet.initialChildSize, AttachGallerySheet.initialSize);
      expect(sheet.minChildSize, AttachGallerySheet.minSize);
      expect(sheet.maxChildSize, AttachGallerySheet.maxSize);
      // La grilla está cableada al scroll del sheet (arrastrarla lo expande) y
      // hay una manija propia para el gesto.
      expect(find.byKey(const Key('attach_gallery.handle')), findsOneWidget);
      final grid = tester.widget<GridView>(
        find.byKey(const Key('attach_gallery.grid')),
      );
      expect(grid.controller, isNotNull);
    });

    testWidgets('tocar una miniatura la selecciona con badge numerado', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        widget: host(gallery: _FakeGallery(_threeAssets)),
      );
      await openSheet(tester);

      expect(find.byKey(const Key('attach_gallery.check.a1')), findsNothing);
      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('attach_gallery.check.a1')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Tocarla de nuevo la desmarca.
      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attach_gallery.check.a1')), findsNothing);
      expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);
    });

    testWidgets('Adjuntar (n) devuelve la selección en orden de tap', (
      tester,
    ) async {
      AttachMenuResult? result;
      await pumpPhone(
        tester,
        widget: host(
          gallery: _FakeGallery(_threeAssets),
          onResult: (r) => result = r,
        ),
      );
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('attach_gallery.item.a2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attach_gallery.item.a1')));
      await tester.pumpAndSettle();

      expect(find.text('Adjuntar (2)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('attach_gallery.confirm')));
      await tester.pumpAndSettle();

      expect(result, isA<AttachMenuGalleryPick>());
      final pick = result! as AttachMenuGalleryPick;
      expect(pick.assets.map((a) => a.id), <String>['a2', 'a1']);
    });

    testWidgets('carrete vacío muestra un estado vacío razonable', (
      tester,
    ) async {
      await pumpPhone(
        tester,
        widget: host(gallery: _FakeGallery(const <DeviceMediaAsset>[])),
      );
      await openSheet(tester);

      expect(find.text('Sin fotos recientes'), findsOneWidget);
      expect(find.byKey(const Key('attach_gallery.confirm')), findsNothing);
    });
  });
}
